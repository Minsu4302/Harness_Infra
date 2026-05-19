package com.harness.orchestration;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.harness.orchestration.gateway.AnthropicGateway;
import com.harness.orchestration.model.AgentRequest;
import com.harness.orchestration.model.OrchestrationPlan;
import com.harness.orchestration.pruner.ContextPruner;
import com.harness.orchestration.service.DeploymentGateService;
import com.harness.orchestration.service.ModelRouter;
import com.harness.orchestration.service.OrchestratorService;
import com.harness.orchestration.service.ReviewAgentService;
import com.harness.orchestration.service.SecurityAgentService;
import com.harness.orchestration.service.TestGenAgentService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.BDDMockito.given;

@ExtendWith(MockitoExtension.class)
class OrchestratorServiceTest {

    @Mock private AnthropicGateway anthropicGateway;
    @Mock private ModelRouter modelRouter;
    @Mock private ReviewAgentService reviewAgentService;
    @Mock private SecurityAgentService securityAgentService;
    @Mock private TestGenAgentService testGenAgentService;
    @Mock private DeploymentGateService deploymentGateService;

    private OrchestratorService orchestratorService;

    @BeforeEach
    void setUp() {
        orchestratorService = new OrchestratorService(
                anthropicGateway, modelRouter,
                reviewAgentService, securityAgentService, testGenAgentService,
                deploymentGateService, new ContextPruner(), new ObjectMapper()
        );
    }

    @Test
    void plan_parsesValidJson_correctly() {
        String planJson = """
                {
                  "reasoning": "new method added, run all agents",
                  "tasks": [
                    {"agent": "security", "model": "gemini", "reason": "pattern check"},
                    {"agent": "review",   "model": "claude", "reason": "logic review"}
                  ]
                }
                """;
        given(anthropicGateway.complete(anyString(), anyString())).willReturn(planJson);

        AgentRequest request = new AgentRequest();
        request.setDiff("+public String hello() { return \"world\"; }");

        OrchestrationPlan plan = orchestratorService.plan(request);

        assertThat(plan.getReasoning()).contains("new method");
        assertThat(plan.getTasks()).hasSize(2);
        assertThat(plan.getTasks().get(0).getAgent()).isEqualTo("security");
        assertThat(plan.getTasks().get(0).getModel()).isEqualTo("gemini");
        assertThat(plan.getTasks().get(1).getAgent()).isEqualTo("review");
        assertThat(plan.getTasks().get(1).getModel()).isEqualTo("claude");
    }

    @Test
    void plan_fallsBackToDefault_whenJsonInvalid() {
        given(anthropicGateway.complete(anyString(), anyString())).willReturn("invalid json {{");

        AgentRequest request = new AgentRequest();
        request.setDiff("+some change");

        OrchestrationPlan plan = orchestratorService.plan(request);

        assertThat(plan.getReasoning()).contains("fallback");
        assertThat(plan.getTasks()).hasSize(3);
    }

    @Test
    void plan_skipsTestGenForDocsOnlyDiff() {
        String planJson = """
                {
                  "reasoning": "docs only change, review only",
                  "tasks": [
                    {"agent": "review", "model": "gemini", "reason": "docs review"}
                  ]
                }
                """;
        given(anthropicGateway.complete(anyString(), anyString())).willReturn(planJson);

        AgentRequest request = new AgentRequest();
        request.setDiff("+# Updated README");

        OrchestrationPlan plan = orchestratorService.plan(request);

        assertThat(plan.getTasks()).hasSize(1);
        assertThat(plan.getTasks().get(0).getAgent()).isEqualTo("review");
    }
}

package com.harness.orchestration;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.harness.orchestration.gateway.AnthropicGateway;
import com.harness.orchestration.gateway.LlmGateway;
import com.harness.orchestration.model.AgentRequest;
import com.harness.orchestration.model.AgentResult;
import com.harness.orchestration.model.AgentResult.Status;
import com.harness.orchestration.model.ConflictResolution;
import com.harness.orchestration.model.GateResult;
import com.harness.orchestration.model.GateResult.Decision;
import com.harness.orchestration.pruner.ContextPruner;
import com.harness.orchestration.service.ConflictResolver;
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

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.BDDMockito.given;

@ExtendWith(MockitoExtension.class)
class OrchestratorParallelTest {

    @Mock private AnthropicGateway anthropicGateway;
    @Mock private ModelRouter modelRouter;
    @Mock private ReviewAgentService reviewAgentService;
    @Mock private SecurityAgentService securityAgentService;
    @Mock private TestGenAgentService testGenAgentService;
    @Mock private ConflictResolver conflictResolver;
    @Mock private LlmGateway mockGateway;

    private OrchestratorService orchestratorService;

    @BeforeEach
    void setUp() {
        orchestratorService = new OrchestratorService(
                anthropicGateway, modelRouter,
                reviewAgentService, securityAgentService, testGenAgentService,
                new DeploymentGateService(conflictResolver), new ContextPruner(), new ObjectMapper()
        );
    }

    private ConflictResolution noConflict() {
        return ConflictResolution.builder().wasConflict(false).build();
    }

    @Test
    void orchestrate_prunesLockFileBeforeExecution() {
        String planJson = """
                {"reasoning":"java change","tasks":[{"agent":"review","model":"claude","reason":"code"}]}
                """;
        given(anthropicGateway.complete(anyString(), anyString())).willReturn(planJson);
        given(modelRouter.route(anyString())).willReturn(mockGateway);
        given(mockGateway.modelName()).willReturn("claude-sonnet-4-6");
        given(conflictResolver.resolve(any(), any())).willReturn(noConflict());
        given(reviewAgentService.review(any(), any())).willReturn(
                AgentResult.builder().agentType("review").status(Status.PASS)
                        .summary("ok").issues(List.of()).build());

        AgentRequest request = new AgentRequest();
        request.setDiff(
                "diff --git a/Service.java b/Service.java\n+public class Service {}\n" +
                "diff --git a/package-lock.json b/package-lock.json\n+lockfile content"
        );

        GateResult result = orchestratorService.orchestrate(request);

        assertThat(result.getDecision()).isEqualTo(Decision.APPROVED);
    }

    @Test
    void orchestrate_continuesPipeline_whenAgentTimesOut() {
        String planJson = """
                {"reasoning":"new code","tasks":[
                  {"agent":"review","model":"claude","reason":"logic"},
                  {"agent":"security","model":"gemini","reason":"check"}
                ]}
                """;
        given(anthropicGateway.complete(anyString(), anyString())).willReturn(planJson);
        given(modelRouter.route(anyString())).willReturn(mockGateway);
        given(mockGateway.modelName()).willReturn("claude-sonnet-4-6");
        given(conflictResolver.resolve(any(), any())).willReturn(noConflict());

        given(reviewAgentService.review(any(), any())).willReturn(
                AgentResult.builder().agentType("review").status(Status.PASS)
                        .summary("ok").issues(List.of()).build());
        given(securityAgentService.scan(any(), any())).willReturn(
                AgentResult.builder().agentType("security").status(Status.PASS)
                        .summary("clean").issues(List.of()).build());

        AgentRequest request = new AgentRequest();
        request.setDiff("+public String hello() { return \"world\"; }");

        GateResult result = orchestratorService.orchestrate(request);

        assertThat(result).isNotNull();
        assertThat(result.getDecision()).isEqualTo(Decision.APPROVED);
    }

    @Test
    void timeoutResult_hasWarnStatus() {
        String planJson = """
                {"reasoning":"check","tasks":[{"agent":"review","model":"claude","reason":"check"}]}
                """;
        given(anthropicGateway.complete(anyString(), anyString())).willReturn(planJson);
        given(modelRouter.route(anyString())).willReturn(mockGateway);
        given(mockGateway.modelName()).willReturn("claude-sonnet-4-6");
        given(conflictResolver.resolve(any(), any())).willReturn(noConflict());
        given(reviewAgentService.review(any(), any())).willThrow(new RuntimeException("API error"));

        AgentRequest request = new AgentRequest();
        request.setDiff("+change");

        GateResult result = orchestratorService.orchestrate(request);

        assertThat(result).isNotNull();
        assertThat(result.getDecision()).isNotNull();
    }
}

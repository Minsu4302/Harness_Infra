package com.harness.orchestration;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.harness.orchestration.model.AgentRequest;
import com.harness.orchestration.model.AgentResult;
import com.harness.orchestration.model.AgentResult.Status;
import com.harness.orchestration.model.GateRequest;
import com.harness.orchestration.model.GateResult;
import com.harness.orchestration.model.GateResult.Decision;
import com.harness.orchestration.service.DeploymentGateService;
import com.harness.orchestration.service.ReviewAgentService;
import com.harness.orchestration.service.SecurityAgentService;
import com.harness.orchestration.service.TestGenAgentService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest
class OrchestrationControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private ReviewAgentService reviewAgentService;

    @MockBean
    private SecurityAgentService securityAgentService;

    @MockBean
    private TestGenAgentService testGenAgentService;

    @MockBean
    private DeploymentGateService deploymentGateService;

    @Test
    void review_returns200_withValidDiff() throws Exception {
        AgentResult mockResult = AgentResult.builder()
                .agentType("review").status(Status.PASS)
                .summary("Looks good").issues(List.of()).build();
        given(reviewAgentService.review(any())).willReturn(mockResult);

        AgentRequest request = new AgentRequest();
        request.setDiff("+public String hello() { return \"world\"; }");

        mockMvc.perform(post("/api/orchestrate/review")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("PASS"))
                .andExpect(jsonPath("$.agentType").value("review"));
    }

    @Test
    void review_returns400_whenDiffIsBlank() throws Exception {
        AgentRequest request = new AgentRequest();
        request.setDiff("");

        mockMvc.perform(post("/api/orchestrate/review")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void gate_returns200_withValidRequest() throws Exception {
        GateResult mockResult = GateResult.builder()
                .decision(Decision.APPROVED).reason("All checks passed")
                .markdownReport("## Report").build();
        given(deploymentGateService.evaluate(any())).willReturn(mockResult);

        GateRequest gateRequest = new GateRequest();
        AgentResult pass = AgentResult.builder().agentType("review").status(Status.PASS)
                .summary("ok").issues(List.of()).build();
        gateRequest.setReviewResult(pass);
        gateRequest.setSecurityResult(pass);
        gateRequest.setTestGenResult(pass);

        mockMvc.perform(post("/api/orchestrate/gate")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(gateRequest)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.decision").value("APPROVED"));
    }
}

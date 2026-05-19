package com.harness.orchestration;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.harness.orchestration.model.AgentRequest;
import com.harness.orchestration.model.GateResult;
import com.harness.orchestration.model.GateResult.Decision;
import com.harness.orchestration.service.OrchestratorService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest
class OrchestrationControllerTest {

    @Autowired private MockMvc mockMvc;
    @Autowired private ObjectMapper objectMapper;
    @MockBean  private OrchestratorService orchestratorService;

    @Test
    void orchestrate_returns200_withValidDiff() throws Exception {
        GateResult mockResult = GateResult.builder()
                .decision(Decision.APPROVED).reason("All checks passed")
                .markdownReport("## Report").build();
        given(orchestratorService.orchestrate(any())).willReturn(mockResult);

        AgentRequest request = new AgentRequest();
        request.setDiff("+public String hello() { return \"world\"; }");

        mockMvc.perform(post("/api/orchestrate")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.decision").value("APPROVED"));
    }

    @Test
    void orchestrate_returns400_whenDiffIsBlank() throws Exception {
        AgentRequest request = new AgentRequest();
        request.setDiff("");

        mockMvc.perform(post("/api/orchestrate")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest());
    }
}

package com.harness.orchestration;

import com.harness.orchestration.model.AgentResult;
import com.harness.orchestration.model.AgentResult.Status;
import com.harness.orchestration.model.GateRequest;
import com.harness.orchestration.model.GateResult;
import com.harness.orchestration.model.GateResult.Decision;
import com.harness.orchestration.service.DeploymentGateService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class DeploymentGateServiceTest {

    private DeploymentGateService gateService;

    @BeforeEach
    void setUp() {
        gateService = new DeploymentGateService();
    }

    @Test
    void approve_whenAllAgentsPass() {
        GateRequest request = buildRequest(Status.PASS, Status.PASS, Status.PASS);

        GateResult result = gateService.evaluate(request);

        assertThat(result.getDecision()).isEqualTo(Decision.APPROVED);
        assertThat(result.getReason()).isEqualTo("All checks passed");
        assertThat(result.getMarkdownReport()).contains("APPROVED");
    }

    @Test
    void reject_whenSecurityFails() {
        GateRequest request = buildRequest(Status.PASS, Status.FAIL, Status.PASS);

        GateResult result = gateService.evaluate(request);

        assertThat(result.getDecision()).isEqualTo(Decision.REJECTED);
        assertThat(result.getReason()).contains("security vulnerabilities");
        assertThat(result.getMarkdownReport()).contains("REJECTED");
    }

    @Test
    void reject_whenReviewFails() {
        GateRequest request = buildRequest(Status.FAIL, Status.PASS, Status.PASS);

        GateResult result = gateService.evaluate(request);

        assertThat(result.getDecision()).isEqualTo(Decision.REJECTED);
        assertThat(result.getReason()).contains("code review failed");
    }

    @Test
    void approve_whenReviewWarnButSecurityPass() {
        GateRequest request = buildRequest(Status.WARN, Status.PASS, Status.PASS);

        GateResult result = gateService.evaluate(request);

        assertThat(result.getDecision()).isEqualTo(Decision.APPROVED);
    }

    @Test
    void reject_whenBothSecurityAndReviewFail() {
        GateRequest request = buildRequest(Status.FAIL, Status.FAIL, Status.PASS);

        GateResult result = gateService.evaluate(request);

        assertThat(result.getDecision()).isEqualTo(Decision.REJECTED);
        assertThat(result.getReason()).contains("security vulnerabilities").contains("code review failed");
    }

    @Test
    void report_containsAllAgentSummaries() {
        GateRequest request = buildRequest(Status.PASS, Status.PASS, Status.PASS);

        GateResult result = gateService.evaluate(request);

        assertThat(result.getMarkdownReport())
                .contains("Code Review")
                .contains("Security Scan")
                .contains("Test Generation");
    }

    private GateRequest buildRequest(Status reviewStatus, Status securityStatus, Status testGenStatus) {
        GateRequest request = new GateRequest();
        request.setReviewResult(AgentResult.builder()
                .agentType("review").status(reviewStatus)
                .summary("review summary").issues(List.of()).build());
        request.setSecurityResult(AgentResult.builder()
                .agentType("security").status(securityStatus)
                .summary("security summary").issues(List.of()).build());
        request.setTestGenResult(AgentResult.builder()
                .agentType("test-gen").status(testGenStatus)
                .summary("test summary").issues(List.of()).generatedCode("").build());
        return request;
    }
}

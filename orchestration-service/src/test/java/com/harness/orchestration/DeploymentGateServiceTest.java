package com.harness.orchestration;

import com.harness.orchestration.model.AgentResult;
import com.harness.orchestration.model.AgentResult.Status;
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
        GateResult result = gateService.evaluate(agent("review", Status.PASS), agent("security", Status.PASS), agent("test-gen", Status.PASS));

        assertThat(result.getDecision()).isEqualTo(Decision.APPROVED);
        assertThat(result.getReason()).isEqualTo("All checks passed");
    }

    @Test
    void reject_whenSecurityFails() {
        GateResult result = gateService.evaluate(agent("review", Status.PASS), agent("security", Status.FAIL), agent("test-gen", Status.PASS));

        assertThat(result.getDecision()).isEqualTo(Decision.REJECTED);
        assertThat(result.getReason()).contains("security vulnerabilities");
    }

    @Test
    void reject_whenReviewFails() {
        GateResult result = gateService.evaluate(agent("review", Status.FAIL), agent("security", Status.PASS), agent("test-gen", Status.PASS));

        assertThat(result.getDecision()).isEqualTo(Decision.REJECTED);
        assertThat(result.getReason()).contains("code review failed");
    }

    @Test
    void approve_whenReviewWarnButSecurityPass() {
        GateResult result = gateService.evaluate(agent("review", Status.WARN), agent("security", Status.PASS), agent("test-gen", Status.PASS));

        assertThat(result.getDecision()).isEqualTo(Decision.APPROVED);
    }

    @Test
    void reject_whenBothFail() {
        GateResult result = gateService.evaluate(agent("review", Status.FAIL), agent("security", Status.FAIL), agent("test-gen", Status.PASS));

        assertThat(result.getDecision()).isEqualTo(Decision.REJECTED);
        assertThat(result.getReason()).contains("security vulnerabilities").contains("code review failed");
    }

    @Test
    void report_containsAllAgentSummaries() {
        GateResult result = gateService.evaluate(agent("review", Status.PASS), agent("security", Status.PASS), agent("test-gen", Status.PASS));

        assertThat(result.getMarkdownReport())
                .contains("Code Review")
                .contains("Security Scan")
                .contains("Test Generation");
    }

    private AgentResult agent(String type, Status status) {
        return AgentResult.builder()
                .agentType(type).status(status)
                .summary(type + " summary").issues(List.of()).build();
    }
}

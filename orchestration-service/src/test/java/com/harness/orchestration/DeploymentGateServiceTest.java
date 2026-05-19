package com.harness.orchestration;

import com.harness.orchestration.model.AgentResult;
import com.harness.orchestration.model.AgentResult.Status;
import com.harness.orchestration.model.ConflictResolution;
import com.harness.orchestration.model.GateResult;
import com.harness.orchestration.model.GateResult.Decision;
import com.harness.orchestration.service.ConflictResolver;
import com.harness.orchestration.service.DeploymentGateService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;

@ExtendWith(MockitoExtension.class)
class DeploymentGateServiceTest {

    @Mock
    private ConflictResolver conflictResolver;

    private DeploymentGateService gateService;

    @BeforeEach
    void setUp() {
        gateService = new DeploymentGateService(conflictResolver);
    }

    private ConflictResolution noConflict() {
        return ConflictResolution.builder().wasConflict(false).build();
    }

    private ConflictResolution claudeDecision(Decision d, String reason) {
        return ConflictResolution.builder()
                .wasConflict(true).decision(d).reason(reason).build();
    }

    @Test
    void approve_whenAllAgentsPass() {
        given(conflictResolver.resolve(any(), any())).willReturn(noConflict());

        GateResult result = gateService.evaluate(agent("review", Status.PASS), agent("security", Status.PASS), agent("test-gen", Status.PASS));

        assertThat(result.getDecision()).isEqualTo(Decision.APPROVED);
        assertThat(result.getReason()).isEqualTo("All checks passed");
    }

    @Test
    void reject_whenBothFail_noConflict() {
        given(conflictResolver.resolve(any(), any())).willReturn(noConflict());

        GateResult result = gateService.evaluate(agent("review", Status.FAIL), agent("security", Status.FAIL), agent("test-gen", Status.PASS));

        assertThat(result.getDecision()).isEqualTo(Decision.REJECTED);
        assertThat(result.getReason()).contains("security").contains("code review");
    }

    @Test
    void approve_whenReviewWarnSecurityPass_noConflict() {
        given(conflictResolver.resolve(any(), any())).willReturn(noConflict());

        GateResult result = gateService.evaluate(agent("review", Status.WARN), agent("security", Status.PASS), agent("test-gen", Status.PASS));

        assertThat(result.getDecision()).isEqualTo(Decision.APPROVED);
    }

    @Test
    void conflict_claudeApproves_overridesReviewFail() {
        given(conflictResolver.resolve(any(), any()))
                .willReturn(claudeDecision(Decision.APPROVED, "[Claude arbitration] minor style issue, security is clean"));

        GateResult result = gateService.evaluate(agent("review", Status.FAIL), agent("security", Status.PASS), agent("test-gen", Status.PASS));

        assertThat(result.getDecision()).isEqualTo(Decision.APPROVED);
        assertThat(result.getReason()).contains("Claude arbitration");
    }

    @Test
    void conflict_claudeRejects_whenSecurityFailReviewPass() {
        given(conflictResolver.resolve(any(), any()))
                .willReturn(claudeDecision(Decision.REJECTED, "[Claude arbitration] SQL injection risk outweighs clean review"));

        GateResult result = gateService.evaluate(agent("review", Status.PASS), agent("security", Status.FAIL), agent("test-gen", Status.PASS));

        assertThat(result.getDecision()).isEqualTo(Decision.REJECTED);
        assertThat(result.getReason()).contains("Claude arbitration");
    }

    @Test
    void report_contains_details_tags() {
        given(conflictResolver.resolve(any(), any())).willReturn(noConflict());

        GateResult result = gateService.evaluate(agent("review", Status.PASS), agent("security", Status.PASS), agent("test-gen", Status.PASS));

        assertThat(result.getMarkdownReport())
                .contains("<details>")
                .contains("<summary>")
                .contains("</details>")
                .contains("Code Review")
                .contains("Security Scan")
                .contains("Test Generation");
    }

    @Test
    void report_contains_conflict_note_when_arbitrated() {
        given(conflictResolver.resolve(any(), any()))
                .willReturn(claudeDecision(Decision.APPROVED, "[Claude arbitration] safe to merge"));

        GateResult result = gateService.evaluate(agent("review", Status.FAIL), agent("security", Status.PASS), agent("test-gen", Status.PASS));

        assertThat(result.getMarkdownReport()).contains("Conflict detected");
    }

    private AgentResult agent(String type, Status status) {
        return AgentResult.builder()
                .agentType(type).status(status)
                .summary(type + " summary").issues(List.of()).build();
    }
}

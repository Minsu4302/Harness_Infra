package com.harness.orchestration;

import com.harness.orchestration.gateway.AnthropicGateway;
import com.harness.orchestration.model.AgentResult;
import com.harness.orchestration.model.AgentResult.Status;
import com.harness.orchestration.model.ConflictResolution;
import com.harness.orchestration.model.GateResult.Decision;
import com.harness.orchestration.service.ConflictResolver;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.BDDMockito.given;

@ExtendWith(MockitoExtension.class)
class ConflictResolverTest {

    @Mock
    private AnthropicGateway anthropicGateway;

    private ConflictResolver conflictResolver;

    @BeforeEach
    void setUp() {
        conflictResolver = new ConflictResolver(anthropicGateway);
    }

    // --- isConflict ---

    @Test
    void isConflict_reviewFail_securityPass_true() {
        assertThat(conflictResolver.isConflict(agent(Status.FAIL), agent(Status.PASS))).isTrue();
    }

    @Test
    void isConflict_reviewPass_securityFail_true() {
        assertThat(conflictResolver.isConflict(agent(Status.PASS), agent(Status.FAIL))).isTrue();
    }

    @Test
    void isConflict_bothFail_false() {
        assertThat(conflictResolver.isConflict(agent(Status.FAIL), agent(Status.FAIL))).isFalse();
    }

    @Test
    void isConflict_bothPass_false() {
        assertThat(conflictResolver.isConflict(agent(Status.PASS), agent(Status.PASS))).isFalse();
    }

    @Test
    void isConflict_warnAndPass_false() {
        assertThat(conflictResolver.isConflict(agent(Status.WARN), agent(Status.PASS))).isFalse();
    }

    // --- parseResolution ---

    @Test
    void parseResolution_approved() {
        ConflictResolution res = conflictResolver.parseResolution(
                "DECISION: APPROVED\nREASON: minor style issue, security is clean");

        assertThat(res.getDecision()).isEqualTo(Decision.APPROVED);
        assertThat(res.getReason()).contains("Claude arbitration");
        assertThat(res.isWasConflict()).isTrue();
    }

    @Test
    void parseResolution_rejected() {
        ConflictResolution res = conflictResolver.parseResolution(
                "DECISION: REJECTED\nREASON: SQL injection risk outweighs style concerns");

        assertThat(res.getDecision()).isEqualTo(Decision.REJECTED);
        assertThat(res.getReason()).contains("Claude arbitration");
    }

    @Test
    void parseResolution_malformed_defaultsToRejected() {
        ConflictResolution res = conflictResolver.parseResolution("invalid response");

        assertThat(res.getDecision()).isEqualTo(Decision.REJECTED);
        assertThat(res.isWasConflict()).isTrue();
    }

    // --- resolve ---

    @Test
    void resolve_noConflict_returnsWasConflictFalse() {
        ConflictResolution res = conflictResolver.resolve(agent(Status.PASS), agent(Status.PASS));

        assertThat(res.isWasConflict()).isFalse();
    }

    @Test
    void resolve_conflict_delegatesToClaude() {
        given(anthropicGateway.complete(anyString(), anyString()))
                .willReturn("DECISION: APPROVED\nREASON: review concern is minor");

        ConflictResolution res = conflictResolver.resolve(agent(Status.FAIL), agent(Status.PASS));

        assertThat(res.isWasConflict()).isTrue();
        assertThat(res.getDecision()).isEqualTo(Decision.APPROVED);
    }

    private AgentResult agent(Status status) {
        return AgentResult.builder()
                .agentType("test").status(status)
                .summary("summary for " + status).issues(List.of()).build();
    }
}

package com.harness.orchestration.service;

import com.harness.orchestration.model.AgentResult;
import com.harness.orchestration.model.AgentResult.Status;
import com.harness.orchestration.model.GateResult;
import com.harness.orchestration.model.GateResult.Decision;
import org.springframework.stereotype.Service;

@Service
public class DeploymentGateService {

    public GateResult evaluate(AgentResult review, AgentResult security, AgentResult testGen) {

        boolean securityBlocking = security.getStatus() == Status.FAIL;
        boolean reviewBlocking = review.getStatus() == Status.FAIL;

        Decision decision = (securityBlocking || reviewBlocking)
                ? Decision.REJECTED
                : Decision.APPROVED;

        String reason = buildReason(review, security, securityBlocking, reviewBlocking);
        String report = buildMarkdownReport(review, security, testGen, decision);

        return GateResult.builder()
                .decision(decision)
                .reason(reason)
                .markdownReport(report)
                .build();
    }

    private String buildReason(AgentResult review, AgentResult security,
                                boolean securityBlocking, boolean reviewBlocking) {
        if (securityBlocking && reviewBlocking) {
            return "Blocked: security vulnerabilities detected + code review failed";
        } else if (securityBlocking) {
            return "Blocked: security vulnerabilities detected — " + security.getSummary();
        } else if (reviewBlocking) {
            return "Blocked: code review failed — " + review.getSummary();
        }
        return "All checks passed";
    }

    private String buildMarkdownReport(AgentResult review, AgentResult security,
                                        AgentResult testGen, Decision decision) {
        String badge = decision == Decision.APPROVED
                ? "✅ **APPROVED**"
                : "❌ **REJECTED**";

        return """
                ## AI Orchestration Gate Report

                %s

                | Agent | Status | Summary |
                |-------|--------|---------|
                | Code Review | %s | %s |
                | Security Scan | %s | %s |
                | Test Generation | %s | %s |

                ### Generated Tests
                ```java
                %s
                ```
                """.formatted(
                badge,
                statusEmoji(review.getStatus()), review.getSummary(),
                statusEmoji(security.getStatus()), security.getSummary(),
                statusEmoji(testGen.getStatus()), testGen.getSummary(),
                testGen.getGeneratedCode() != null ? testGen.getGeneratedCode() : "(none)"
        );
    }

    private String statusEmoji(Status status) {
        return switch (status) {
            case PASS -> "✅ PASS";
            case WARN -> "⚠️ WARN";
            case FAIL -> "❌ FAIL";
        };
    }
}

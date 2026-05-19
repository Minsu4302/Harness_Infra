package com.harness.orchestration.service;

import com.harness.orchestration.model.AgentResult;
import com.harness.orchestration.model.AgentResult.Status;
import com.harness.orchestration.model.ConflictResolution;
import com.harness.orchestration.model.GateResult;
import com.harness.orchestration.model.GateResult.Decision;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class DeploymentGateService {

    private final ConflictResolver conflictResolver;

    public GateResult evaluate(AgentResult review, AgentResult security, AgentResult testGen) {
        ConflictResolution conflict = conflictResolver.resolve(review, security);

        Decision decision;
        String reason;

        if (conflict.isWasConflict()) {
            decision = conflict.getDecision();
            reason   = conflict.getReason();
        } else {
            boolean securityBlocking = security.getStatus() == Status.FAIL;
            boolean reviewBlocking   = review.getStatus()   == Status.FAIL;
            decision = (securityBlocking || reviewBlocking) ? Decision.REJECTED : Decision.APPROVED;
            reason   = buildReason(review, security, securityBlocking, reviewBlocking);
        }

        String report = buildMarkdownReport(review, security, testGen, decision, conflict);

        return GateResult.builder()
                .decision(decision)
                .reason(reason)
                .markdownReport(report)
                .build();
    }

    private String buildReason(AgentResult review, AgentResult security,
                                boolean securityBlocking, boolean reviewBlocking) {
        if (securityBlocking && reviewBlocking) return "Blocked: security vulnerabilities + code review failed";
        if (securityBlocking) return "Blocked: security vulnerabilities — " + security.getSummary();
        if (reviewBlocking)   return "Blocked: code review failed — " + review.getSummary();
        return "All checks passed";
    }

    private String buildMarkdownReport(AgentResult review, AgentResult security,
                                        AgentResult testGen, Decision decision,
                                        ConflictResolution conflict) {
        String badge = decision == Decision.APPROVED ? "✅ **APPROVED**" : "❌ **REJECTED**";
        String conflictNote = conflict.isWasConflict()
                ? "\n> ⚖️ **Conflict detected** — Claude arbitrated: " + conflict.getReason() + "\n"
                : "";
        String testGenCode = testGen.getGeneratedCode() != null ? testGen.getGeneratedCode() : "(none)";

        return """
                ## 🤖 AI Orchestration Gate Report

                %s
                %s
                <details>
                <summary>📋 Code Review — %s</summary>

                **Summary:** %s
                %s
                </details>

                <details>
                <summary>🔒 Security Scan — %s</summary>

                **Summary:** %s
                %s
                </details>

                <details>
                <summary>🧪 Test Generation — %s</summary>

                **Summary:** %s

                ```java
                %s
                ```

                </details>
                """.formatted(
                badge,
                conflictNote,
                statusEmoji(review.getStatus()),   review.getSummary(),   buildIssuesList(review.getIssues()),
                statusEmoji(security.getStatus()), security.getSummary(), buildIssuesList(security.getIssues()),
                statusEmoji(testGen.getStatus()),   testGen.getSummary(),  testGenCode
        );
    }

    private String buildIssuesList(List<String> issues) {
        if (issues == null || issues.isEmpty()) return "";
        var sb = new StringBuilder("\n**Issues:**\n");
        for (String issue : issues) sb.append("- ").append(issue).append("\n");
        return sb.toString();
    }

    private String statusEmoji(Status status) {
        return switch (status) {
            case PASS -> "✅ PASS";
            case WARN -> "⚠️ WARN";
            case FAIL -> "❌ FAIL";
        };
    }
}

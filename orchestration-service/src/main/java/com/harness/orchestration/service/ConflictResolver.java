package com.harness.orchestration.service;

import com.harness.orchestration.gateway.AnthropicGateway;
import com.harness.orchestration.model.AgentResult;
import com.harness.orchestration.model.AgentResult.Status;
import com.harness.orchestration.model.ConflictResolution;
import com.harness.orchestration.model.GateResult.Decision;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class ConflictResolver {

    private final AnthropicGateway anthropicGateway;

    private static final String RESOLVER_PROMPT = """
            You are a deployment gate arbitrator. Two AI agents have reviewed the same code change
            and reached conflicting conclusions. Analyze their findings and make a final decision.

            Respond ONLY in this exact format (no markdown, no extra text):
            DECISION: APPROVED
            REASON: <one sentence>

            or

            DECISION: REJECTED
            REASON: <one sentence>
            """;

    public boolean isConflict(AgentResult review, AgentResult security) {
        boolean reviewFail = review.getStatus() == Status.FAIL;
        boolean securityFail = security.getStatus() == Status.FAIL;
        return reviewFail ^ securityFail;
    }

    public ConflictResolution resolve(AgentResult review, AgentResult security) {
        if (!isConflict(review, security)) {
            return ConflictResolution.builder()
                    .wasConflict(false)
                    .build();
        }

        log.info("[ConflictResolver] conflict detected — review={}, security={}, delegating to Claude",
                review.getStatus(), security.getStatus());

        String userMessage = """
                Code Review Agent result: %s — %s
                Security Scan Agent result: %s — %s

                These agents disagree. Make the final deployment gate decision.
                """.formatted(
                review.getStatus(), review.getSummary(),
                security.getStatus(), security.getSummary()
        );

        String response = anthropicGateway.complete(RESOLVER_PROMPT, userMessage);
        return parseResolution(response);
    }

    public ConflictResolution parseResolution(String response) {
        try {
            String[] lines = response.trim().split("\n");
            String decisionLine = "";
            String reasonLine = "";
            for (String line : lines) {
                String trimmed = line.trim();
                if (trimmed.startsWith("DECISION:")) decisionLine = trimmed.substring(9).trim();
                if (trimmed.startsWith("REASON:"))   reasonLine   = trimmed.substring(7).trim();
            }
            Decision decision = decisionLine.equalsIgnoreCase("APPROVED")
                    ? Decision.APPROVED
                    : Decision.REJECTED;
            return ConflictResolution.builder()
                    .decision(decision)
                    .reason("[Claude arbitration] " + reasonLine)
                    .wasConflict(true)
                    .build();
        } catch (Exception e) {
            log.warn("[ConflictResolver] parse failed, defaulting to REJECTED: {}", e.getMessage());
            return ConflictResolution.builder()
                    .decision(Decision.REJECTED)
                    .reason("[Claude arbitration] parse error — defaulting to safe REJECTED")
                    .wasConflict(true)
                    .build();
        }
    }
}

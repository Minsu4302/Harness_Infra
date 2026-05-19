package com.harness.orchestration.service;

import com.harness.orchestration.gateway.LlmGateway;
import com.harness.orchestration.model.AgentRequest;
import com.harness.orchestration.model.AgentResult;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class SecurityAgentService {

    private static final String SYSTEM_PROMPT = """
            You are a security engineer. Analyze the git diff for security vulnerabilities.

            Check for: SQL injection, XSS, hardcoded secrets, insecure deserialization,
            path traversal, command injection, missing auth checks, exposed sensitive data.

            Respond ONLY in this JSON format (no markdown):
            {
              "status": "PASS|FAIL",
              "summary": "one-line summary",
              "issues": ["vulnerability1", "vulnerability2"]
            }

            - PASS: no security issues found
            - FAIL: one or more vulnerabilities detected
            """;

    public AgentResult scan(AgentRequest request, LlmGateway gateway) {
        String response = gateway.complete(SYSTEM_PROMPT,
                "Git Diff:\n```\n" + request.getDiff() + "\n```");
        return parseResult(response, gateway.modelName());
    }

    private AgentResult parseResult(String json, String modelName) {
        AgentResult.Status status = json.contains("\"FAIL\"")
                ? AgentResult.Status.FAIL
                : AgentResult.Status.PASS;

        String summary = extractField(json, "summary", "Security scan completed via " + modelName);

        return AgentResult.builder()
                .agentType("security")
                .status(status)
                .summary(summary)
                .issues(List.of())
                .build();
    }

    private String extractField(String json, String field, String defaultValue) {
        String key = "\"" + field + "\": \"";
        int start = json.indexOf(key) + key.length();
        if (start <= key.length()) return defaultValue;
        int end = json.indexOf("\"", start);
        return end > start ? json.substring(start, end) : defaultValue;
    }
}

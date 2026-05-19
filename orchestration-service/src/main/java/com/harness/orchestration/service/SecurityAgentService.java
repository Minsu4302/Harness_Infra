package com.harness.orchestration.service;

import com.anthropic.client.AnthropicClient;
import com.anthropic.models.messages.Message;
import com.anthropic.models.messages.MessageCreateParams;
import com.anthropic.models.messages.Model;
import com.harness.orchestration.model.AgentRequest;
import com.harness.orchestration.model.AgentResult;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class SecurityAgentService {

    private final AnthropicClient anthropicClient;

    @Value("${anthropic.model}")
    private String model;

    @Value("${anthropic.max-tokens}")
    private int maxTokens;

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

    public AgentResult scan(AgentRequest request) {
        Message message = anthropicClient.messages().create(
                MessageCreateParams.builder()
                        .model(Model.of(model))
                        .maxTokens(maxTokens)
                        .system(SYSTEM_PROMPT)
                        .addUserMessage("Git Diff:\n```\n" + request.getDiff() + "\n```")
                        .build()
        );

        String content = message.content().stream()
                .filter(block -> block.isText())
                .map(block -> block.asText().text())
                .findFirst()
                .orElse("{}");

        return parseResult(content);
    }

    private AgentResult parseResult(String json) {
        AgentResult.Status status = json.contains("\"FAIL\"") || json.contains("\"status\":\"FAIL\"")
                ? AgentResult.Status.FAIL
                : AgentResult.Status.PASS;

        String summary = extractField(json, "summary", "Security scan completed");

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

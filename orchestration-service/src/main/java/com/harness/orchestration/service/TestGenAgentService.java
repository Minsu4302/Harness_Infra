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
public class TestGenAgentService {

    private final AnthropicClient anthropicClient;

    @Value("${anthropic.model}")
    private String model;

    @Value("${anthropic.max-tokens}")
    private int maxTokens;

    private static final String SYSTEM_PROMPT = """
            You are a test engineer. Given a git diff, generate unit test code for new or changed methods.

            Respond ONLY in this JSON format (no markdown wrapping the JSON itself):
            {
              "status": "PASS",
              "summary": "one-line summary of what tests cover",
              "test_code": "full test class code here"
            }

            Requirements:
            - Use JUnit 5 and Mockito
            - Cover happy path + at least one edge case per method
            - If diff has no testable code changes, set test_code to empty string
            """;

    public AgentResult generate(AgentRequest request) {
        String prompt = "Language: " + request.getLanguage() + "\n\n"
                + "Git Diff:\n```\n" + request.getDiff() + "\n```";

        Message message = anthropicClient.messages().create(
                MessageCreateParams.builder()
                        .model(Model.of(model))
                        .maxTokens(maxTokens)
                        .system(SYSTEM_PROMPT)
                        .addUserMessage(prompt)
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
        String summary = extractField(json, "summary", "Test generation completed");
        String testCode = extractTestCode(json);

        return AgentResult.builder()
                .agentType("test-gen")
                .status(AgentResult.Status.PASS)
                .summary(summary)
                .issues(List.of())
                .generatedCode(testCode)
                .build();
    }

    private String extractField(String json, String field, String defaultValue) {
        String key = "\"" + field + "\": \"";
        int start = json.indexOf(key) + key.length();
        if (start <= key.length()) return defaultValue;
        int end = json.indexOf("\"", start);
        return end > start ? json.substring(start, end) : defaultValue;
    }

    private String extractTestCode(String json) {
        String key = "\"test_code\": \"";
        int start = json.indexOf(key);
        if (start < 0) return "";
        start += key.length();
        int end = json.lastIndexOf("\"");
        return end > start ? json.substring(start, end).replace("\\n", "\n").replace("\\\"", "\"") : "";
    }
}

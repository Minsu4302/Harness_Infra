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
public class ReviewAgentService {

    private final AnthropicClient anthropicClient;

    @Value("${anthropic.model}")
    private String model;

    @Value("${anthropic.max-tokens}")
    private int maxTokens;

    private static final String SYSTEM_PROMPT = """
            You are a senior code reviewer. Analyze the provided git diff and return a structured review.

            Respond ONLY in this JSON format (no markdown):
            {
              "status": "PASS|WARN|FAIL",
              "summary": "one-line summary",
              "issues": ["issue1", "issue2"]
            }

            Rules:
            - PASS: clean diff, no significant issues
            - WARN: minor issues (style, naming, missing comments)
            - FAIL: serious issues (logic bugs, missing error handling, broken patterns)
            """;

    public AgentResult review(AgentRequest request) {
        String userMessage = buildUserMessage(request);

        Message message = anthropicClient.messages().create(
                MessageCreateParams.builder()
                        .model(Model.of(model))
                        .maxTokens(maxTokens)
                        .system(SYSTEM_PROMPT)
                        .addUserMessage(userMessage)
                        .build()
        );

        String content = extractText(message);
        return parseResult(content);
    }

    private String buildUserMessage(AgentRequest request) {
        StringBuilder sb = new StringBuilder();
        if (request.getPrTitle() != null) {
            sb.append("PR Title: ").append(request.getPrTitle()).append("\n\n");
        }
        sb.append("Git Diff:\n```\n").append(request.getDiff()).append("\n```");
        return sb.toString();
    }

    private String extractText(Message message) {
        return message.content().stream()
                .filter(block -> block.isText())
                .map(block -> block.asText().text())
                .findFirst()
                .orElse("{}");
    }

    private AgentResult parseResult(String json) {
        try {
            AgentResult.Status status = AgentResult.Status.WARN;
            String summary = "Review completed";
            List<String> issues = List.of();

            if (json.contains("\"status\": \"PASS\"") || json.contains("\"status\":\"PASS\"")) {
                status = AgentResult.Status.PASS;
            } else if (json.contains("\"status\": \"FAIL\"") || json.contains("\"status\":\"FAIL\"")) {
                status = AgentResult.Status.FAIL;
            }

            int summaryStart = json.indexOf("\"summary\": \"") + 12;
            if (summaryStart > 11) {
                int summaryEnd = json.indexOf("\"", summaryStart);
                if (summaryEnd > summaryStart) {
                    summary = json.substring(summaryStart, summaryEnd);
                }
            }

            return AgentResult.builder()
                    .agentType("review")
                    .status(status)
                    .summary(summary)
                    .issues(issues)
                    .build();
        } catch (Exception e) {
            return AgentResult.builder()
                    .agentType("review")
                    .status(AgentResult.Status.WARN)
                    .summary("Review parsing failed: " + e.getMessage())
                    .issues(List.of())
                    .build();
        }
    }
}

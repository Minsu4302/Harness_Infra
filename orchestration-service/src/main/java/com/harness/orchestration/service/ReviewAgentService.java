package com.harness.orchestration.service;

import com.harness.orchestration.gateway.LlmGateway;
import com.harness.orchestration.model.AgentRequest;
import com.harness.orchestration.model.AgentResult;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class ReviewAgentService {

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

    public AgentResult review(AgentRequest request, LlmGateway gateway) {
        String response = gateway.complete(SYSTEM_PROMPT, buildUserMessage(request));
        return parseResult(response, gateway.modelName());
    }

    private String buildUserMessage(AgentRequest request) {
        StringBuilder sb = new StringBuilder();
        if (request.getPrTitle() != null) {
            sb.append("PR Title: ").append(request.getPrTitle()).append("\n\n");
        }
        sb.append("Git Diff:\n```\n").append(request.getDiff()).append("\n```");
        return sb.toString();
    }

    private AgentResult parseResult(String json, String modelName) {
        AgentResult.Status status = AgentResult.Status.WARN;
        if (json.contains("\"PASS\"")) status = AgentResult.Status.PASS;
        else if (json.contains("\"FAIL\"")) status = AgentResult.Status.FAIL;

        String summary = extractField(json, "summary", "Review completed via " + modelName);

        return AgentResult.builder()
                .agentType("review")
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

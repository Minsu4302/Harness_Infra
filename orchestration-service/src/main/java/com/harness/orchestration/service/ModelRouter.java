package com.harness.orchestration.service;

import com.harness.orchestration.gateway.AnthropicGateway;
import com.harness.orchestration.gateway.GeminiGateway;
import com.harness.orchestration.gateway.LlmGateway;
import com.harness.orchestration.gateway.OpenAiGateway;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class ModelRouter {

    private final AnthropicGateway anthropicGateway;
    private final GeminiGateway geminiGateway;
    private final OpenAiGateway openAiGateway;

    public LlmGateway route(String model) {
        return switch (model.toLowerCase()) {
            case "gemini" -> geminiGateway;
            case "gpt"    -> openAiGateway;
            default       -> anthropicGateway;
        };
    }
}

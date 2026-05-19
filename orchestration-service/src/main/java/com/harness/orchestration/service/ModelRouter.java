package com.harness.orchestration.service;

import com.harness.orchestration.gateway.AnthropicGateway;
import com.harness.orchestration.gateway.GeminiGateway;
import com.harness.orchestration.gateway.LlmGateway;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class ModelRouter {

    private final AnthropicGateway anthropicGateway;
    private final GeminiGateway geminiGateway;

    public LlmGateway route(String model) {
        return switch (model.toLowerCase()) {
            case "gemini" -> geminiGateway;
            default       -> anthropicGateway;
        };
    }
}

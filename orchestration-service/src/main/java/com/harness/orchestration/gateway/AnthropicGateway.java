package com.harness.orchestration.gateway;

import com.anthropic.client.AnthropicClient;
import com.anthropic.models.messages.MessageCreateParams;
import com.anthropic.models.messages.Model;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class AnthropicGateway implements LlmGateway {

    private final AnthropicClient anthropicClient;

    @Value("${anthropic.model}")
    private String model;

    @Value("${anthropic.max-tokens}")
    private int maxTokens;

    @Override
    public String complete(String systemPrompt, String userMessage) {
        return anthropicClient.messages()
                .create(MessageCreateParams.builder()
                        .model(Model.of(model))
                        .maxTokens(maxTokens)
                        .system(systemPrompt)
                        .addUserMessage(userMessage)
                        .build())
                .content().stream()
                .filter(b -> b.isText())
                .map(b -> b.asText().text())
                .findFirst()
                .orElse("");
    }

    @Override
    public String modelName() {
        return model;
    }
}

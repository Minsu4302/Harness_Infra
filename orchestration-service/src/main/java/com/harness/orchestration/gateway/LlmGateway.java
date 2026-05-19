package com.harness.orchestration.gateway;

public interface LlmGateway {

    String complete(String systemPrompt, String userMessage);

    String modelName();
}

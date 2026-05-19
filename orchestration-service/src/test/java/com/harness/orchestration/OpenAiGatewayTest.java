package com.harness.orchestration;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.harness.orchestration.gateway.OpenAiGateway;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class OpenAiGatewayTest {

    private OpenAiGateway gateway;

    @BeforeEach
    void setUp() {
        gateway = new OpenAiGateway(new ObjectMapper());
    }

    @Test
    void extractText_parsesValidResponse() {
        String response = """
                {
                  "choices": [
                    {
                      "message": {
                        "role": "assistant",
                        "content": "Here is the generated test code."
                      }
                    }
                  ]
                }
                """;

        String result = gateway.extractText(response);

        assertThat(result).isEqualTo("Here is the generated test code.");
    }

    @Test
    void extractText_returnsEmpty_whenChoicesEmpty() {
        String response = """
                {
                  "choices": []
                }
                """;

        String result = gateway.extractText(response);

        assertThat(result).isEmpty();
    }

    @Test
    void extractText_returnsEmpty_whenContentMissing() {
        String response = """
                {
                  "choices": [
                    { "message": {} }
                  ]
                }
                """;

        String result = gateway.extractText(response);

        assertThat(result).isEmpty();
    }

    @Test
    void extractText_throwsOnMalformedJson() {
        assertThatThrownBy(() -> gateway.extractText("not valid json {{"))
                .isInstanceOf(RuntimeException.class)
                .hasMessageContaining("Failed to parse OpenAI response");
    }
}

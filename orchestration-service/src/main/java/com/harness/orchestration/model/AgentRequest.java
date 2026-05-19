package com.harness.orchestration.model;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class AgentRequest {

    @NotBlank
    private String diff;

    private String prTitle;
    private String prDescription;
    private String language = "java";
}

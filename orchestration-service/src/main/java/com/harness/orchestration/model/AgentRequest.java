package com.harness.orchestration.model;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class AgentRequest {

    @NotNull
    private String diff;

    private String prTitle;
    private String prDescription;
    private String language = "java";
}

package com.harness.orchestration.controller;

import com.harness.orchestration.model.AgentRequest;
import com.harness.orchestration.model.GateResult;
import com.harness.orchestration.service.OrchestratorService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/orchestrate")
@RequiredArgsConstructor
public class OrchestrationController {

    private final OrchestratorService orchestratorService;

    @PostMapping
    public ResponseEntity<GateResult> orchestrate(@Valid @RequestBody AgentRequest request) {
        return ResponseEntity.ok(orchestratorService.orchestrate(request));
    }
}

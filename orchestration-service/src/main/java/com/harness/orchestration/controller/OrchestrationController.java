package com.harness.orchestration.controller;

import com.harness.orchestration.model.AgentRequest;
import com.harness.orchestration.model.AgentResult;
import com.harness.orchestration.model.GateRequest;
import com.harness.orchestration.model.GateResult;
import com.harness.orchestration.service.DeploymentGateService;
import com.harness.orchestration.service.ReviewAgentService;
import com.harness.orchestration.service.SecurityAgentService;
import com.harness.orchestration.service.TestGenAgentService;
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

    private final ReviewAgentService reviewAgentService;
    private final SecurityAgentService securityAgentService;
    private final TestGenAgentService testGenAgentService;
    private final DeploymentGateService deploymentGateService;

    @PostMapping("/review")
    public ResponseEntity<AgentResult> review(@Valid @RequestBody AgentRequest request) {
        return ResponseEntity.ok(reviewAgentService.review(request));
    }

    @PostMapping("/security")
    public ResponseEntity<AgentResult> security(@Valid @RequestBody AgentRequest request) {
        return ResponseEntity.ok(securityAgentService.scan(request));
    }

    @PostMapping("/test-gen")
    public ResponseEntity<AgentResult> testGen(@Valid @RequestBody AgentRequest request) {
        return ResponseEntity.ok(testGenAgentService.generate(request));
    }

    @PostMapping("/gate")
    public ResponseEntity<GateResult> gate(@Valid @RequestBody GateRequest request) {
        return ResponseEntity.ok(deploymentGateService.evaluate(request));
    }
}

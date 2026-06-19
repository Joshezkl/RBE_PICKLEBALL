<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\SessionPreset;
use App\Services\SessionPresetService;
use App\Support\MatchMode;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SessionPresetController extends Controller
{
    public function __construct(private SessionPresetService $presetService) {}

    public function index(): JsonResponse
    {
        return response()->json([
            'presets' => $this->presetService->list(),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:120',
            'match_mode' => 'required|string|in:'.implode(',', MatchMode::ALL),
            'play_format' => 'sometimes|in:doubles,singles',
            'court_count' => 'sometimes|integer|min:1|max:12',
            'auto_assign_enabled' => 'sometimes|boolean',
            'match_mode_settings' => 'sometimes|array',
        ]);

        $preset = $this->presetService->create($validated);

        return response()->json($this->presetService->format($preset), 201);
    }

    public function update(Request $request, SessionPreset $preset): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'sometimes|string|max:120',
            'match_mode' => 'sometimes|string|in:'.implode(',', MatchMode::ALL),
            'play_format' => 'sometimes|in:doubles,singles',
            'court_count' => 'sometimes|integer|min:1|max:12',
            'auto_assign_enabled' => 'sometimes|boolean',
            'match_mode_settings' => 'sometimes|array',
        ]);

        $preset = $this->presetService->update($preset, $validated);

        return response()->json($this->presetService->format($preset));
    }

    public function destroy(SessionPreset $preset): JsonResponse
    {
        $this->presetService->delete($preset);

        return response()->json(['message' => 'Preset deleted']);
    }
}

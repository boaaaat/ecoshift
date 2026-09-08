# EcoShift matchmaking configuration

Roblox chooses the **public Lobby server** when someone joins. Its native matching already considers signals including latency, text chat and language. Reserved servers are excluded from that public-server ranking, so EcoShift's cross-server queue must separately assemble and reserve each exact six-player expedition. [Roblox matchmaking](https://create.roblox.com/docs/matchmaking), [native signals](https://create.roblox.com/docs/matchmaking/attributes-and-signals).

On September 7, 2026, `EcoShift Expedition Lobbies` was created and verified in Creator Dashboard's Applied Places table for **Ecoshift** (`120274921310527`) and the secondary place (`94125768885713`, then named Lobby, now **Expedition**). Final routing uses `120274921310527` as the public entry lobby and `94125768885713` as the reserved expedition destination. The configuration was applied to both places, but its public-server ranking governs entry lobby selection, not reserved expedition assignment. Publication and live travel validation are tracked in `validation-2026-09-07.md`.

The configuration uses Occupancy 2, Age 1, Language 3, Latency 4, Friends 15, Device Type 0, Voice Chat 1, Play History 2, Text Chat 5, and the custom class-diversity signal 4. The age signal remains a Roblox-owned ranking preference, not a game-enforced age admission rule. The dashboard's mock preview ran successfully; it does not establish published cross-server party/teleport correctness.

The custom attribute `EcoShiftClass` (String, default `Generalist`) and signal `Complementary Expedition Classes` (player categorical, **Diversify**) were saved. No communication API opt-in or terms acceptance has been performed.

## Reproducing the enabled class-diversity configuration

In Creator Dashboard → EcoShift → Configure → Custom Matchmaking:

1. Create a **player categorical attribute**, named `EcoShiftClass`, type String, default `Generalist`.
2. Connect it to the existing profile store below; the selected class already persists there.
3. Create a custom player categorical signal using that attribute and **Diversify**.
4. Add it to a configuration retaining Roblox's latency, text-chat and language signals. Apply the configuration to the public entry lobby, **Ecoshift**, place `120274921310527` (`SessionConfig.LobbyPlaceId`). The secondary place **Expedition**, `94125768885713`, is the expedition destination.

Roblox documents Diversify as favoring servers containing other attribute values. This improves the lobby's potential class mix; it does not guarantee a six-class expedition. Signal weights are deployment tuning, and should be reviewed using the dashboard's configuration preview. [Configuration instructions](https://create.roblox.com/docs/matchmaking/customize-matchmaking).

| Profile mapping | Current source value |
| --- | --- |
| Data store | `EcoshiftProfile_v1` |
| Scope | `global` |
| Key template | `{UserId}` |
| Value path | `$.Role` (top-level `Role` field) |
| Existing values | `Generalist`, `Builder`, `Hunter`, `Gatherer`, `Engineer`, `Medic` |

These values come from `Shared/Config.lua` and `Services/ProfileService.lua`. Native player attributes read DataStore data; a `Player:SetAttribute()` call alone does not configure this native signal. [Attribute storage](https://create.roblox.com/docs/matchmaking/attributes-and-signals#custom-attributes).

## Optional real-time text-chat compatibility

The owner must enable **Chat & Voice Groups APIs** under Studio's Experience Settings → Communication and accept Roblox's terms before `TextChatService:GetChatGroupsAsync()` can supply groups. Studio supports this API in **Team Test**, not ordinary solo/local play. If unavailable, EcoShift records `Unknown` and still allows queueing. [API requirements](https://create.roblox.com/docs/reference/engine/classes/TextChatService#GetChatGroupsAsync).

`RobloxMatchmakingSignals.Capture(player)` only accepts players currently on that server. It returns class, language preference, native matchmaking type and transient opaque chat groups. Matching IDs are a current communication hint. The code does not infer age, use account age as a substitute, or override Roblox's communication permissions.

Roblox requires chat-group data to be discarded when a player leaves. Keep it out of profiles, persistent parties, rejoin records, teleport data, client remotes and logs. A live queue may use temporary MemoryStore hints; remove them on cancellation/departure/teleport, refresh while queued, and use a short crash-expiry TTL. `Signals.Invalidated` fires on local departure; local cached groups are cleared automatically. [Data lifetime](https://create.roblox.com/docs/reference/engine/classes/TextChatService#GetChatGroupsAsync).

## Queue integration

```lua
local signal, reason = Signals.Capture(player)
-- Only the queue owner may store this transient record.
local ticket = {
    Id = party.Id,
    QueuedAt = originalQueueTime,
    ExpiresAt = os.time() + 60,
    MatchmakingType = Signals.MatchmakingType(),
    Members = { signal }, -- every online, ready member; never a partial party
}

local match, reason = Policy.Choose(tickets, {
    Now = os.time(),
    MatchmakingType = Signals.MatchmakingType(),
})
```

`Policy.Score(tickets, now)` returns a score and aggregate diagnostics. `Policy.Choose()` returns `{Parties, PartyIds, Members, MatchmakingType, Score, Diagnostics}`. Results remain server-only because they include the transient input signals.

Selection requires exactly six distinct players, intact parties, fresh signals and one matching native type (`Default`, `XboxOnly`, or `PlayStationOnly`). Unknown type cannot match. Within a bounded snapshot, the oldest feasible party is served first. Other parties are scored for class diversity, shared chat groups, shared language and waiting time; communication access is never an entry requirement. As the oldest wait grows from 30 to 150 seconds, waiting fairness gets more weight. No short expedition launches automatically.

Each call inspects at most 100 input tickets, searches at most 20 candidates, and visits at most 40,000 states. The oldest fourteen tickets plus representatives of missing party sizes keep the search bounded. The diagnostics flag a truncated search; these bounds do not prove a globally optimal match across the entire live queue.

The queue service must claim tickets atomically, recheck ready rosters and presence, cancel on disconnect or class change, merge matched parties, and only then reserve/teleport the six players. Successful policy selection alone does not authorize teleporting a stale roster.

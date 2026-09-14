# Furnace repair and focused verification

The furnace now groups recipes by available materials and station/campaign locks. Recipe details show inventory counts against the selected batch cost, a maximum quantity shortcut, and fuel controls. The header displays stored fuel and the current work state. Successful queue actions open the output/queue page.

Station requests receive explicit results, including throttled requests. Completed request IDs reuse their result rather than charging twice. Jobs are prepared before payment, cancellations target stable job IDs and refund the actual paid inputs, and output collection checks the expected item. Restored output maps normalize numeric/string slot indices; capacity checks inspect all twelve output slots rather than depending on array length.

## Authorized Studio checks

The user explicitly requested a test after reporting that materials disappeared. Checks ran in Expedition play mode using temporary runtime fixtures, normal station remotes, and MCP gameplay input. Studio was returned to Edit mode afterward; fixtures were not saved to the source or published.

- One Wood added 15 seconds of stored fuel and deducted one Wood. The actual Fuel page button also passed.
- Nine Iron Ore appeared as materials for six Iron Bars. The selected recipe displayed `9 / 3` owned/needed.
- One queued batch consumed three Iron Ore, completed into two Iron Bars, and used six seconds of fuel. The actual Smelt button opened the queue page after acknowledgment.
- Clicking the output collected two Iron Bars into inventory and cleared the output slot.
- Cancelling a paused job returned all three reserved Iron Ore without spending fuel.
- Repeating an identical fuel request ID charged once and returned the original receipt.
- An unaffordable two-batch request rejected without taking the remaining three Iron Ore.
- A furnace restored from string-keyed output slots accepted work, waited at zero fuel with `Needs fuel`, resumed after fuel was added, and merged the new bars into existing output. Fuel debit remained six seconds.
- The Fuel page was visually inspected through a Studio capture. Physical mobile touch was not tested.

The original published-session log was unavailable, so its exact failure was not reproduced. The repaired fuel, work, collection, and refund paths passed the checks above. An unrelated existing `WorldControlUI` call to `Theme.Button` with a TextBox produced an initialization error; that survey UI issue was not changed in this furnace patch.

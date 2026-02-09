ExUnit.start(exclude: [:external])
Ecto.Adapters.SQL.Sandbox.mode(Pearl.Repo, :manual)

# Ensure Settings ETS table exists for tests that use Pearl.Config.
# We only create the table (not load from DB) since Sandbox is in manual mode.
if :ets.whereis(:pearl_settings) == :undefined do
  :ets.new(:pearl_settings, [:set, :public, :named_table])
end

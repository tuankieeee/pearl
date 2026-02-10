ExUnit.start(exclude: [:external])
Ecto.Adapters.SQL.Sandbox.mode(Pearl.Repo, :manual)

# Define Mox mocks
Mox.defmock(Pearl.RagMock, for: Pearl.Rag.Behaviour)

# Create the Settings ETS table manually instead of starting Pearl.Settings GenServer.
# Rationale: The GenServer's init/1 immediately attempts to load settings from the
# database via handle_continue(:load_from_db), but in :manual sandbox mode no
# connection is checked out yet, causing DBConnection errors. Creating just the
# ETS table allows Pearl.Config (which reads from ETS) to work, falling back to
# defaults when keys aren't found.
if :ets.whereis(:pearl_settings) == :undefined do
  :ets.new(:pearl_settings, [:set, :public, :named_table])
end

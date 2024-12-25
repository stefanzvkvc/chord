# Define mocks for behaviors
Mox.defmock(Chord.Support.Mocks.Backend, for: Chord.Backend.Behaviour)
Mox.defmock(Chord.Support.Mocks.Redis, for: Chord.Utils.Redis.Behaviour)
Mox.defmock(Chord.Support.Mocks.Time, for: Chord.Utils.Time.Behaviour)

/// Which copy wins when the phone and the account both have a pantry row.
enum PantrySyncAction { keepLocal, takeRemote, deleteLocal }

PantrySyncAction decidePantrySync({
  required DateTime? localUpdated,
  required DateTime remoteUpdated,
  DateTime? remoteDeleted,
}) {
  if (remoteDeleted != null) {
    if (localUpdated != null && localUpdated.isAfter(remoteDeleted)) {
      return PantrySyncAction.keepLocal;
    }
    return PantrySyncAction.deleteLocal;
  }
  if (localUpdated == null || remoteUpdated.isAfter(localUpdated)) {
    return PantrySyncAction.takeRemote;
  }
  return PantrySyncAction.keepLocal;
}

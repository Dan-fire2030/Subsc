import type { Subscription } from "../db/subscriptions";

const DB_NAME = "subsc-offline";
const DB_VERSION = 1;
const SNAPSHOTS = "snapshots";
const OPERATIONS = "operations";

export type SyncOperation =
  | {
      opId: string;
      userEmail: string;
      type: "upsert";
      subscription: Subscription;
      createdAt: number;
    }
  | {
      opId: string;
      userEmail: string;
      type: "delete";
      id: number;
      clientId: string;
      createdAt: number;
    };

function requestResult<T>(request: IDBRequest<T>) {
  return new Promise<T>((resolve, reject) => {
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

function transactionDone(transaction: IDBTransaction) {
  return new Promise<void>((resolve, reject) => {
    transaction.oncomplete = () => resolve();
    transaction.onerror = () => reject(transaction.error);
    transaction.onabort = () => reject(transaction.error);
  });
}

function openDatabase() {
  return new Promise<IDBDatabase>((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onupgradeneeded = () => {
      const database = request.result;
      if (!database.objectStoreNames.contains(SNAPSHOTS)) {
        database.createObjectStore(SNAPSHOTS, { keyPath: "userEmail" });
      }
      if (!database.objectStoreNames.contains(OPERATIONS)) {
        database.createObjectStore(OPERATIONS, { keyPath: "opId" });
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

export async function loadSnapshot(userEmail: string) {
  if (!("indexedDB" in window)) return null;
  const database = await openDatabase();
  const transaction = database.transaction(SNAPSHOTS, "readonly");
  const value = await requestResult<{
    userEmail: string;
    subscriptions: Subscription[];
  } | undefined>(transaction.objectStore(SNAPSHOTS).get(userEmail));
  database.close();
  return value?.subscriptions ?? null;
}

export async function saveSnapshot(
  userEmail: string,
  subscriptions: Subscription[],
) {
  if (!("indexedDB" in window)) return;
  const database = await openDatabase();
  const transaction = database.transaction(SNAPSHOTS, "readwrite");
  transaction.objectStore(SNAPSHOTS).put({
    userEmail,
    subscriptions,
    updatedAt: Date.now(),
  });
  await transactionDone(transaction);
  database.close();
}

export async function enqueueOperation(operation: SyncOperation) {
  if (!("indexedDB" in window)) return;
  const database = await openDatabase();
  const transaction = database.transaction(OPERATIONS, "readwrite");
  transaction.objectStore(OPERATIONS).put(operation);
  await transactionDone(transaction);
  database.close();
}

export async function listOperations(userEmail: string) {
  if (!("indexedDB" in window)) return [] as SyncOperation[];
  const database = await openDatabase();
  const transaction = database.transaction(OPERATIONS, "readonly");
  const operations = await requestResult<SyncOperation[]>(
    transaction.objectStore(OPERATIONS).getAll(),
  );
  database.close();
  return operations
    .filter((operation) => operation.userEmail === userEmail)
    .toSorted((a, b) => a.createdAt - b.createdAt);
}

export async function removeOperation(opId: string) {
  if (!("indexedDB" in window)) return;
  const database = await openDatabase();
  const transaction = database.transaction(OPERATIONS, "readwrite");
  transaction.objectStore(OPERATIONS).delete(opId);
  await transactionDone(transaction);
  database.close();
}

export async function clearOfflineData(userEmail: string) {
  if (!("indexedDB" in window)) return;
  const database = await openDatabase();
  const existing = await listOperations(userEmail);
  const transaction = database.transaction([SNAPSHOTS, OPERATIONS], "readwrite");
  transaction.objectStore(SNAPSHOTS).delete(userEmail);
  for (const operation of existing) {
    transaction.objectStore(OPERATIONS).delete(operation.opId);
  }
  await transactionDone(transaction);
  database.close();
}

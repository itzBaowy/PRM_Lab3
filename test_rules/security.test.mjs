import { before, after, beforeEach, test } from 'node:test';
import fs from 'node:fs/promises';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, updateDoc, serverTimestamp, Timestamp, writeBatch } from 'firebase/firestore';
import { ref, uploadBytes, getBytes } from 'firebase/storage';

let env;
const owner = 'lecturer';
const email = 'student@example.test';
before(async () => {
  env = await initializeTestEnvironment({projectId:'demo-fap-attendance', firestore:{rules:await fs.readFile('firebase/firestore.rules','utf8')}, storage:{rules:await fs.readFile('firebase/storage.rules','utf8')}});
});
after(async () => { await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(doc(db,'attendanceSessions/session1'),{ownerUid:owner,open:true,codeEnabled:true,updatedAt:Timestamp.now()});
    await setDoc(doc(db,`attendanceSessions/session1/members/${email}`),{studentId:'SE000001',name:'Test Student'});
    await setDoc(doc(db,'attendanceSessions/session1/private/code'),{code:'123456'});
  });
});
const studentDb = (verified=true) => env.authenticatedContext('student',{email,email_verified:verified}).firestore();
async function visit(db) { await setDoc(doc(db,'attendanceSessions/session1/visits/student'),{startedAt:serverTimestamp()}); }
function submit(db,code='123456') { return setDoc(doc(db,`attendanceSessions/session1/submissions/${email}`),{studentId:'SE000001',uid:'student',code,submittedAt:serverTimestamp()}); }

test('workspace requires matching owner and monotonically increasing revision', async () => {
  const db = env.authenticatedContext(owner).firestore();
  const target = doc(db,`workspaces/${owner}`);
  await assertSucceeds(setDoc(target,{ownerUid:owner,revision:1,payload:{ownerUid:owner}}));
  await assertFails(updateDoc(target,{revision:3}));
  await assertSucceeds(updateDoc(target,{revision:2}));
  await assertFails(getDoc(doc(env.authenticatedContext('other').firestore(),`workspaces/${owner}`)));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),`workspaces/${owner}`)));
});
test('verified member can read own details but never private code or another member', async () => {
  const db = studentDb();
  await assertSucceeds(getDoc(doc(db,'attendanceSessions/session1')));
  await assertSucceeds(getDoc(doc(db,`attendanceSessions/session1/members/${email}`)));
  await assertFails(getDoc(doc(db,'attendanceSessions/session1/private/code')));
  await assertFails(getDoc(doc(db,'attendanceSessions/session1/members/other@example.test')));
});
test('outsider and unverified identities cannot open session', async () => {
  await assertFails(getDoc(doc(studentDb(false),'attendanceSessions/session1')));
  const outsider = env.authenticatedContext('outside',{email:'outside@example.test',email_verified:true}).firestore();
  await assertFails(getDoc(doc(outsider,'attendanceSessions/session1')));
});
test('submission requires a visit, correct code and rejects duplicate writes', async () => {
  const db = studentDb();
  await assertFails(submit(db));
  await assertSucceeds(visit(db));
  await assertFails(submit(db,'999999'));
  await assertSucceeds(submit(db));
  await assertFails(submit(db));
});
test('expired two-minute visit cannot submit', async () => {
  await env.withSecurityRulesDisabled(ctx => setDoc(doc(ctx.firestore(),'attendanceSessions/session1/visits/student'),{startedAt:Timestamp.fromMillis(Date.now()-121000)}));
  await assertFails(submit(studentDb()));
});
test('stopped session rejects submissions and client cannot reopen', async () => {
  const db = studentDb(); await visit(db);
  await updateDoc(doc(env.authenticatedContext(owner).firestore(),'attendanceSessions/session1'),{open:false});
  await assertFails(submit(db));
  await assertFails(updateDoc(doc(db,'attendanceSessions/session1'),{open:true}));
});
test('owner can create a session and private roster in a single batch', async () => {
  const db = env.authenticatedContext(owner).firestore(), batch = writeBatch(db);
  batch.set(doc(db,'attendanceSessions/session2'),{ownerUid:owner,open:true,updatedAt:serverTimestamp(),codeEnabled:false});
  batch.set(doc(db,'attendanceSessions/session2/private/code'),{code:''});
  batch.set(doc(db,`attendanceSessions/session2/members/${email}`),{studentId:'SE000001',name:'Test Student'});
  await assertSucceeds(batch.commit());
});
test('Storage isolates owner paths and permits only generated report MIME types', async () => {
  const storage = env.authenticatedContext(owner).storage();
  await assertSucceeds(uploadBytes(ref(storage,`reports/${owner}/report.json`),new TextEncoder().encode('{}'),{contentType:'application/json'}));
  await assertFails(uploadBytes(ref(storage,'reports/other/report.json'),new TextEncoder().encode('{}'),{contentType:'application/json'}));
  await assertFails(uploadBytes(ref(storage,`reports/${owner}/payload.html`),new TextEncoder().encode('<script/>'),{contentType:'text/html'}));
  await assertFails(getBytes(ref(env.authenticatedContext('other').storage(),`reports/${owner}/report.json`)));
});

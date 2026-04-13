// lib/firebase.ts
import { initializeApp } from "firebase/app";
import { getFirestore } from "firebase/firestore";

const firebaseConfig = {
  apiKey: "AIzaSyB0G72QpLBXBIZ2vjUgknWBnScp1B78enw", // from your JSON
  authDomain: "floodwatch-trivandrum.firebaseapp.com", // usually project_id.firebaseapp.com
  projectId: "floodwatch-trivandrum", // from your JSON
  storageBucket: "floodwatch-trivandrum.firebasestorage.app", // from your JSON
  messagingSenderId: "695214659311", // project_number from your JSON
  appId: "1:695214659311:android:8fcb94f99d49ca945aed1a", // mobilesdk_app_id from your JSON
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

export { db };

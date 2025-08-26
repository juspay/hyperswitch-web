import { BrowserRouter, Routes, Route } from "react-router-dom";
import SubscriptionFlow from "./SubscriptionFlow";
import "./App.css";

function App() {
  return (
    <BrowserRouter
      future={{ v7_startTransition: true, v7_relativeSplatPath: true }}
    >
      <Routes>
        <Route path="/" element={<SubscriptionFlow />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;

import { BrowserRouter, Routes, Route } from "react-router-dom";
import Payment from "./Payment";
import "./App.css";

function App() {
  return (
    <BrowserRouter
      future={{ v7_startTransition: true, v7_relativeSplatPath: true }}
    >
      <Routes>
        <Route path="/" element={<Payment />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;

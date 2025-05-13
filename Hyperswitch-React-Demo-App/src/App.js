import React from "react";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import Payment from "./Payment";
import "./App.css";

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Payment />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;

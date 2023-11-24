import "./App.css";
import Payment from "./Payment";
import Completion from "./Completion";
import React from "react";

import { BrowserRouter, Routes, Route } from "react-router-dom";

function App() {
  return (
    <main>
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<Payment />} />
        </Routes>
      </BrowserRouter>
    </main>
  );
}

export default App;

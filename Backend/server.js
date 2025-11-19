import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import path from "path";
import { fileURLToPath } from "url";
import client from "prom-client"; // <-- Prometheus client

import connectDB from "./config/mongodb.js";
import connectCloudinary from "./config/cloudinary.js";
import userRouter from "./routes/userRoute.js";
import productRouter from "./routes/productRoute.js";
import cartRouter from "./routes/cartRoute.js";
import orderRouter from "./routes/orderRoute.js";
import globaErrorController from "./controllers/globaErrorController.js";
import notFoundPageError from "./routes/notFoundPageError.js";

dotenv.config();

const app = express();
const port = process.env.PORT || 5000;

// ---------------------- Prometheus metrics ----------------------
const requestCounter = new client.Counter({
  name: "app_requests_total",
  help: "Total number of API requests",
});

// Collect default Node.js metrics (CPU, memory, event loop, etc.)
client.collectDefaultMetrics();

// Middleware to count all API requests
app.use("/api", (req, res, next) => {
  requestCounter.inc();
  next();
});

// Metrics endpoint for Prometheus to scrape
app.get("/metrics", async (req, res) => {
  try {
    res.set("Content-Type", client.register.contentType);
    res.end(await client.register.metrics());
  } catch (err) {
    res.status(500).end(err);
  }
});
// -----------------------------------------------------------------

// MongoDB + Cloudinary
connectDB();
connectCloudinary();

// Middlewares
app.use(express.json());
app.use(cors());

// API endpoints
app.use("/api/user", userRouter);
app.use("/api/product", productRouter);
app.use("/api/cart", cartRouter);
app.use("/api/order", orderRouter);

// Serve frontend static files
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
app.use(express.static(path.join(__dirname, "public")));

// React Router fallback
app.get("*", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "index.html"));
});

// Error handlers
app.use(notFoundPageError);
app.use(globaErrorController);

app.listen(port, () => console.log("Server started on port: " + port));


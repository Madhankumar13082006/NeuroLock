"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const dotenv_1 = require("dotenv");
const pino_1 = __importDefault(require("pino"));
const routes_1 = __importDefault(require("./routes"));
const path_1 = __importDefault(require("path"));
require("./jobs/queue");
(0, dotenv_1.config)();
const app = (0, express_1.default)();
const logger = (0, pino_1.default)({ transport: { target: 'pino-pretty' } });
app.use('/approve', express_1.default.static(path_1.default.join(__dirname, '../../web-approval/public')));
app.use((0, cors_1.default)());
app.use(express_1.default.json());
app.use('/', routes_1.default);
app.use((err, req, res, _next) => {
    logger.error(err);
    res.status(500).json({ error: 'Internal server error' });
});
const PORT = process.env.PORT || 3000;
// Bind all interfaces so phones on the same Wi‑Fi can open http://<PC_LAN_IP>:PORT/invite/…
app.listen(Number(PORT), '0.0.0.0', () => logger.info({ port: PORT }, 'Server listening (use LAN IP for invite links from devices)'));
exports.default = app;

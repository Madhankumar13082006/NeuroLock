import express from 'express';
import cors from 'cors';
import { config } from 'dotenv';
import pino from 'pino';
import routes from './routes';
import path from 'path';
import './jobs/queue';
config();
const app = express();
const logger = pino({ transport: { target: 'pino-pretty' } });
app.use('/approve', express.static(path.join(__dirname, '../../web-approval/public')));
app.use(cors());
app.use(express.json());

app.use('/', routes);

app.use((err: Error, req: express.Request, res: express.Response, _next: express.NextFunction) => {
  logger.error(err);
  res.status(500).json({ error: 'Internal server error' });
});

import './jobs/queue'; // boots the fallback + expiry workers

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => logger.info(`Server running on port ${PORT}`));

export default app;
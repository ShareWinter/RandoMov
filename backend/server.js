const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

const server = http.createServer(app);
const io = new Server(server, { cors: { origin: '*' } });

// ==================== In-memory store ====================
const rooms = new Map();
const socketToRoom = new Map(); // socketId -> { roomCode, userId }

function generateCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code = '';
  for (let i = 0; i < 6; i++) code += chars[Math.floor(Math.random() * chars.length)];
  return rooms.has(code) ? generateCode() : code;
}

function hashCode(str) {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    hash = ((hash << 5) - hash) + str.charCodeAt(i);
    hash |= 0;
  }
  return hash;
}

function autoLuckyNumber(userId, roomCode) {
  return (hashCode(userId + roomCode) & 0x7FFFFFFF) % 99 + 1;
}

function toRoomJson(room) {
  return {
    code: room.code,
    hostId: room.hostId,
    participants: room.participants,
    selectedMovieIds: room.selectedMovieIds,
    status: room.status,
    drawResult: room.drawResult,
    moviesById: room.moviesById,
  };
}

// ==================== HTTP ====================
app.get('/health', (_, res) => res.json({ ok: true }));

app.post('/api/rooms', (req, res) => {
  const { hostId, hostName } = req.body;
  if (!hostId || !hostName) return res.status(400).json({ error: '缺少参数' });

  const code = generateCode();
  const room = {
    code,
    hostId,
    participants: [{
      userId: hostId, name: hostName, isHost: true,
      joinedAt: new Date().toISOString(), luckyNumber: null,
    }],
    selectedMovieIds: [],
    status: 'waiting',
    drawResult: null,
    moviesById: {},
    lastActivity: Date.now(),
  };
  rooms.set(code, room);
  console.log(`[Room] Created ${code} by ${hostName}`);
  res.json({ room: toRoomJson(room) });
});

app.get('/api/rooms', (req, res) => {
  const { code } = req.query;
  const room = rooms.get(code);
  if (!room) return res.status(404).json({ error: '房间不存在' });
  room.lastActivity = Date.now();
  res.json({ room: toRoomJson(room) });
});

// Proxy route for WMDB API (bypasses GFW via server-side request)
app.get('/api/movie', async (req, res) => {
  const { id } = req.query;
  if (!id) return res.status(400).json({ error: '缺少 id 参数' });

  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 15000);

    const response = await fetch(
      `https://api.wmdb.tv/movie/api?id=${id}`,
      {
        headers: { 'Accept': 'application/json' },
        signal: controller.signal,
      },
    );
    clearTimeout(timeout);

    if (!response.ok) {
      return res.status(response.status).json({
        error: `WMDB API 返回错误: ${response.status}`,
      });
    }

    const data = await response.json();
    res.json(data);
  } catch (e) {
    if (e.name === 'AbortError') {
      return res.status(504).json({ error: 'WMDB API 请求超时' });
    }
    console.error('[Proxy] WMDB API error:', e.message);
    res.status(502).json({ error: `代理请求失败: ${e.message}` });
  }
});

// ==================== Socket.IO ====================
io.on('connection', (socket) => {
  console.log(`[Socket] Connected: ${socket.id}`);

  socket.on('join-room', ({ roomCode, userId, userName }) => {
    const room = rooms.get(roomCode);
    if (!room) return socket.emit('error', { message: '房间不存在' });
    if (room.status === 'drawing' || room.status === 'collecting') {
      return socket.emit('error', { message: '抽奖进行中，无法加入' });
    }

    room.lastActivity = Date.now();
    const existing = room.participants.find(p => p.userId === userId);
    if (existing) {
      existing.name = userName; // reconnect: update name
    } else {
      room.participants.push({
        userId, name: userName, isHost: false,
        joinedAt: new Date().toISOString(), luckyNumber: null,
      });
    }

    socketToRoom.set(socket.id, { roomCode, userId });
    socket.join(roomCode);
    io.to(roomCode).emit('room-updated', { room: toRoomJson(room) });
    console.log(`[Room] ${userName} joined ${roomCode}`);
  });

  socket.on('leave-room', ({ roomCode, userId }) => {
    const room = rooms.get(roomCode);
    if (!room) return;

    if (room.hostId === userId) {
      io.to(roomCode).emit('room-closed', { reason: '房主已离开，房间关闭' });
      rooms.delete(roomCode);
      console.log(`[Room] ${roomCode} closed (host left)`);
    } else {
      room.participants = room.participants.filter(p => p.userId !== userId);
      io.to(roomCode).emit('room-updated', { room: toRoomJson(room) });
    }
    socket.leave(roomCode);
    socketToRoom.delete(socket.id);
  });

  socket.on('update-room-movies', ({ roomCode, userId, movieIds, moviesData }) => {
    const room = rooms.get(roomCode);
    if (!room || room.status !== 'waiting') return;
    if (room.hostId !== userId) return socket.emit('error', { message: '只有房主可以选片' });

    room.lastActivity = Date.now();
    room.selectedMovieIds = movieIds || [];
    if (moviesData) Object.assign(room.moviesById, moviesData);

    io.to(roomCode).emit('room-updated', { room: toRoomJson(room) });
  });

  socket.on('submit-lucky-number', ({ roomCode, userId, luckyNumber }) => {
    const room = rooms.get(roomCode);
    if (!room || room.status !== 'collecting') return;
    if (luckyNumber < 1 || luckyNumber > 99) return socket.emit('error', { message: '幸运数字须为 1-99' });

    const participant = room.participants.find(p => p.userId === userId);
    if (participant) participant.luckyNumber = luckyNumber;
    io.to(roomCode).emit('room-updated', { room: toRoomJson(room) });
  });

  socket.on('start-draw', ({ roomCode, userId }) => {
    const room = rooms.get(roomCode);
    if (!room) return;
    if (room.hostId !== userId) return socket.emit('error', { message: '只有房主可以发起抽奖' });

    if (room.selectedMovieIds.length === 0) return socket.emit('error', { message: '没有候选影片' });

    // Enter collecting phase
    room.status = 'collecting';
    room.lastActivity = Date.now();
    for (const p of room.participants) p.luckyNumber = null;
    io.to(roomCode).emit('room-updated', { room: toRoomJson(room) });

    // 5-second countdown then execute draw
    setTimeout(() => {
      if (!rooms.has(roomCode) || room.status !== 'collecting') return;
      executeDraw(room, room.selectedMovieIds);
    }, 5000);
  });

  socket.on('reset-room', ({ roomCode, userId }) => {
    const room = rooms.get(roomCode);
    if (!room || room.hostId !== userId) return;

    room.status = 'waiting';
    room.drawResult = null;
    room.moviesById = {};
    room.selectedMovieIds = [];
    for (const p of room.participants) {
      p.luckyNumber = null;
    }
    room.lastActivity = Date.now();
    io.to(roomCode).emit('room-reset', { room: toRoomJson(room) });
  });

  socket.on('disconnect', () => {
    const info = socketToRoom.get(socket.id);
    socketToRoom.delete(socket.id);
    if (!info) return;
    console.log(`[Socket] Disconnected: ${socket.id} (${info.userId} in ${info.roomCode})`);
    // Don't remove immediately — allow reconnect
  });
});

function executeDraw(room, allMovieIds) {
  // Auto-fill missing lucky numbers
  const sorted = [...room.participants].sort((a, b) => a.userId.localeCompare(b.userId));
  for (const p of sorted) {
    if (p.luckyNumber == null) {
      p.luckyNumber = autoLuckyNumber(p.userId, room.code);
    }
  }

  // Compute seed
  const timestamp = Date.now();
  const rawSeed = sorted.map(p => p.luckyNumber).join('-') + '-' + timestamp;
  const seed = hashCode(rawSeed) & 0x7FFFFFFF;
  const index = seed % allMovieIds.length;
  const winnerMovieId = allMovieIds[index];
  const movieData = room.moviesById[winnerMovieId] || {};

  // Build candidates array for client animation
  const candidates = allMovieIds.map(id => room.moviesById[id] || { id, title: id });

  // Update room
  room.status = 'drawing';
  io.to(room.code).emit('room-updated', { room: toRoomJson(room) });
  io.to(room.code).emit('draw-started', { seed, candidates });

  // After animation time, finalize
  setTimeout(() => {
    if (!rooms.has(room.code)) return;
    room.drawResult = {
      movieId: winnerMovieId,
      movieTitle: movieData.title || '',
      drawnAt: new Date().toISOString(),
      seed,
    };
    room.status = 'completed';
    io.to(room.code).emit('draw-result', { room: toRoomJson(room) });
  }, 4000);
}

// ==================== Cleanup ====================
setInterval(() => {
  const now = Date.now();
  for (const [code, room] of rooms) {
    if (now - room.lastActivity > 10 * 60 * 1000) {
      io.to(code).emit('room-closed', { reason: '房间超时自动关闭' });
      rooms.delete(code);
      console.log(`[Cleanup] Room ${code} expired`);
    }
  }
}, 60 * 1000);

// ==================== Start ====================
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Server running on port ${PORT} (HTTP + Socket.IO)`);
});

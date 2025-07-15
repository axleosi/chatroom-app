import express from 'express';
import http from 'http';
import mongoose from 'mongoose';
import cors from 'cors';
import { Server } from 'socket.io';
import dotenv from 'dotenv';

import userRoute from './routes/userRoute.js';
import friendRoute from './routes/friendRoute.js';
import messageRoute from './routes/messageRoute.js';
import User from './models/userModel.js';
import Message from './models/messageModel.js';

dotenv.config();

const MONGO_URI = process.env.MONGO_URI;
const PORT = process.env.PORT || 5000;

export const onlineUsers = new Map();

const app = express();
app.use(cors({
  origin: ['https://chatroom-app1.web.app'], // Firebase hosting
  methods: ['GET', 'POST'],
  credentials: true,
}));
app.use(express.json());

const connectDB = async () => {
  try {
    await mongoose.connect(`${MONGO_URI}/chatroom`);
    console.log('✅ MongoDB connected');
  } catch (err) {
    console.error('❌ MongoDB connection error:', err);
  }
};
await connectDB();

app.use('/api', userRoute);
app.use('/api', friendRoute);
app.use('/api', messageRoute);

const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: ['https://chatroom-app1.web.app'],
    methods: ['GET', 'POST'],
    credentials: true,
  }
});

app.set('io', io);

io.on('connection', (socket) => {
  const userId = socket.handshake.query.userId;
  console.log('🟢 New socket connected:', socket.id, '| userId:', userId);

  if (userId) {
    socket.join(userId); // ✅ this is the key
    if (!onlineUsers.has(userId)) {
      onlineUsers.set(userId, new Set());
    }
    onlineUsers.get(userId).add(socket.id);
  }

  socket.on('join', (userRoomId) => {
    console.log(`✅ User ${userId} joining room: ${userRoomId}`);
    socket.join(userRoomId);

    // Optional: Acknowledge room join to client
    socket.emit('room_joined', userRoomId);
  });

  socket.on('send_message', async ({ senderId, receiverId, content }) => {
    console.log('📩 Received send_message:', { senderId, receiverId, content });

    try {
      // Save to database
      const saved = await Message.create({
        sender: senderId,
        receiver: receiverId,
        content,
      });

      console.log('✅ Message saved to DB:', saved._id);

      // Emit to receiver
      io.to(receiverId).emit('receive_message', {
        sender: senderId,
        content,
      });

    } catch (err) {
      console.error('❌ Failed to save message:', err);
    }
  });

  socket.on('typing', ({ to }) => {
    console.log('✍️ Typing event to:', to);
    io.to(to).emit('typing');
  });

  socket.on('stopTyping', ({ to }) => {
    console.log('🛑 Stop typing to:', to);
    io.to(to).emit('stopTyping');
  });

  socket.on('disconnect', async () => {
    console.log('🔌 Disconnected socket:', socket.id);
    if (!userId) return;

    const userSockets = onlineUsers.get(userId);
    if (userSockets) {
      userSockets.delete(socket.id);
      if (userSockets.size === 0) {
        onlineUsers.delete(userId);
        await User.findByIdAndUpdate(userId, { lastSeen: new Date() });
        console.log('🕒 Updated lastSeen for user:', userId);
      }
    }
  });
});

server.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
});

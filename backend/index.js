import express from 'express'
import http from 'http'
import mongoose from 'mongoose'
import cors from 'cors'
import {Server}from 'socket.io'
import userRoute from './routes/userRoute.js'
import friendRoute from './routes/friendRoute.js'
import messageRoute from './routes/messageRoute.js'
import dotenv from 'dotenv'
import User from './models/userModel.js'

dotenv.config()

const MONGO_URI=process.env.MONGO_URI
const PORT=process.env.PORT || 5000

export const onlineUsers = new Map();


const app=express();
app.use(cors());
app.use(express.json())


const connectDB= async()=>{
    await mongoose.connect(`${MONGO_URI}/chatroom`)
    .then(()=> console.log('MongoDB connected'))
    .catch(console.error)
}

await connectDB()

app.use('/api',userRoute)
app.use('/api',friendRoute)
app.use('/api',messageRoute)

const server= http.createServer(app)
const io= new Server(server, {
    cors: {
        origin:'*',
        methods:['*']
    }
})

io.on('connection', (socket) => {
  const userId = socket.handshake.query.userId;


  if (userId) {

    if (!onlineUsers.has(userId)) {
      onlineUsers.set(userId, new Set());
    }
    onlineUsers.get(userId).add(socket.id);
  }

  socket.on('join', (roomId) => {
    socket.join(roomId);

  });

  socket.on('send_message', ({ senderId, receiverId, content }) => {
    io.to(receiverId).emit('receive_message', { sender: senderId, content });
  });

  socket.on('typing', ({ to }) => {
    io.to(to).emit('typing');
  });

  socket.on('stopTyping', ({ to }) => {
    io.to(to).emit('stopTyping');
  });

  socket.on('disconnect', async () => {
    if (!userId) return;

    const userSockets = onlineUsers.get(userId);
    if (userSockets) {
      userSockets.delete(socket.id); 
      if (userSockets.size === 0) {
        onlineUsers.delete(userId);
        await User.findByIdAndUpdate(userId, { lastSeen: new Date() });
      }
    }

  });
});


server.listen(PORT, ()=>{
    console.log('Server running on port 5000');
    
})
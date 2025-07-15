import express from 'express';
import Message from '../models/messageModel.js';
import authenticateToken from '../middleware/authenticateToken.js';

const router = express.Router();

router.post('/message/send', authenticateToken, async (req, res) => {
  const { receiverId, content } = req.body;
  const senderId = req.user._id;

  if (!receiverId || !content) {
    return res.status(400).json({ message: 'Receiver ID and content are required' });
  }

  try {
    const newMessage = await Message.create({
      sender: senderId,
      receiver: receiverId,
      content,
    });

    res.status(201).json({ message: 'Message sent', data: newMessage });

  } catch (err) {
    console.error('❌ Message send error:', err);
    res.status(500).json({ message: 'Server error' });
  }
});


router.get('/message/history/:receiverId', authenticateToken, async (req, res) => {
  const userId = req.params.receiverId;
  const currentUserId = req.user._id;

  try {
    const messages = await Message.find({
      $or: [
        { sender: currentUserId, receiver: userId },
        { sender: userId, receiver: currentUserId },
      ],
    })
      .sort({ timestamp: 1 }) // chronological
      .populate('sender', 'username')
      .populate('receiver', 'username');

    res.status(200).json({ messages });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

router.delete('/message/:id', authenticateToken, async (req, res) => {
  try {
    const message = await Message.findById(req.params.id);

    if (!message) {
      return res.status(404).json({ message: 'Message not found' });
    }

    if (message.sender.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: 'Unauthorized' });
    }

    await message.remove();
    res.status(200).json({ message: 'Message deleted' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});


export default router
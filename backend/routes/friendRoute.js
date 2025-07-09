import express from 'express';
import User from '../models/userModel.js';
import authenticateToken from '../middleware/authenticateToken.js';
import { onlineUsers } from '../index.js';

const router = express.Router();


router.post('/friend/add', authenticateToken, async (req, res) => {
  const { usernameToAdd } = req.body;
  const currentUser = req.user;

  try {
    if (!usernameToAdd) {
      return res.status(400).json({ message: 'Username is required' });
    }

    if (usernameToAdd.toLowerCase() === currentUser.username.toLowerCase()) {
      return res.status(400).json({ message: "You can't add yourself" });
    }

    const userToAdd = await User.findOne({ username: usernameToAdd.toLowerCase() });
    if (!userToAdd) {
      return res.status(404).json({ message: 'User not found' });
    }

    if (currentUser.friends.includes(userToAdd._id)) {
      return res.status(400).json({ message: 'Already friends' });
    }

    currentUser.friends.push(userToAdd._id);
    userToAdd.friends.push(currentUser._id);

    await currentUser.save();
    await userToAdd.save();

    res.status(200).json({ message: `You are now friends with ${usernameToAdd}` });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});


router.post('/friend/remove', authenticateToken, async (req, res) => {
  const { usernameToRemove } = req.body;
  const currentUser = req.user;

  try {
    if (usernameToRemove.toLowerCase() === currentUser.username.toLowerCase()) {
      return res.status(400).json({ message: "You can't remove yourself" });
    }

    const userToRemove = await User.findOne({ username: usernameToRemove.toLowerCase() });
    if (!userToRemove) {
      return res.status(404).json({ message: 'User not found' });
    }

    currentUser.friends = currentUser.friends.filter(
      id => id.toString() !== userToRemove._id.toString()
    );
    userToRemove.friends = userToRemove.friends.filter(
      id => id.toString() !== currentUser._id.toString()
    );

    await currentUser.save();
    await userToRemove.save();

    res.status(200).json({ message: `You removed ${usernameToRemove} from your friends` });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});


router.get('/friend/list', authenticateToken, async (req, res) => {
  try {
    const user = await User.findById(req.user._id).populate('friends', 'username email');
    res.json({ friends: user.friends });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});


router.get('/friend/search', authenticateToken, async (req, res) => {
  const query = req.query.query?.toLowerCase();

  if (!query) {
    return res.status(400).json({ message: 'Query is required' });
  }

  try {
    const users = await User.find({
      username: { $regex: new RegExp(`^${query}`, 'i') },
      _id: { $ne: req.user._id },
    }).select('username email');

    res.json({ results: users });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

router.get('/friend/:id', authenticateToken, async (req, res) => {
  try {
    const friend = await User.findById(req.params.id).select('_id username avatarUrl lastSeen');
    if (!friend) {
      return res.status(404).json({ message: 'Friend not found' });
    }

    const isOnline = onlineUsers.has(friend._id.toString());

    res.json({
      friend: {
        _id: friend._id,
        username: friend.username,
        avatarUrl: friend.avatarUrl,
        lastSeen: friend.lastSeen,
        isOnline,
      },
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});




export default router
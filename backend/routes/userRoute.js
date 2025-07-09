import express from 'express'
import User from '../models/userModel.js'
import generateToken from '../middleware/generateToken.js'
import passwordCheck from '../middleware/passwordCheck.js'
import authenticateToken from '../middleware/authenticateToken.js'

const router = express.Router()


router.post('/signup', async (req, res) => {
  const { username, email, password } = req.body

  try {
    const userExists = await User.findOne({ username })
    if (userExists) {
      return res.status(400).json({ message: 'User already exists' })
    }

    const newUser = await User.create({ username, email, password })

    res.status(201).json({
      _id: newUser._id,
      username: newUser.username,
      email: newUser.email,
      token: generateToken(newUser._id),
    })
  } catch (error) {
    console.error(error)
    res.status(500).json({ message: 'Server error' })
  }
})

router.get('/me', authenticateToken, async (req, res) => {
  try {
    const user = await User.findById(req.user._id).select('-password');
    res.json(user);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});


router.post('/login', passwordCheck, async (req, res) => {
  const user = req.user

  res.json({
    _id: user._id,
    username: user.username,
    email: user.email,
    token: generateToken(user._id),
  })
})


export default router

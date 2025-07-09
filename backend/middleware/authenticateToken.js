import jwt from 'jsonwebtoken'
import User from '../models/userModel.js'
import dotenv from 'dotenv'

dotenv.config();

const JWT_SECRET=process.env.JWT_SECRET
const authenticateToken = async (req,res,next) => {
    const authHeader = req.headers['authorization'];
    let token;

    if (authHeader && (authHeader.startsWith('Bearer ') || authHeader.startsWith('Token '))) {
        token = authHeader.split(' ')[1].trim();
    }

    if (!token) {
        return res.status(401).json({ message: 'Access token missing or malformed' });
    }

    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        const user = await User.findById(decoded.id).select('-password')

        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }

        req.user = user;
        next();
    } catch (err) {
        return res.status(403).json({ message: 'Invalid or expired token', err });
    }
}



export default authenticateToken
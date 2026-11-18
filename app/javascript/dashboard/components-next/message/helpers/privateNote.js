import { MESSAGE_STATUS, SENDER_TYPES } from '../constants';

// COESA: a private note typed by the logged-in agent (or still being sent by them). Every other
// note — from the bot, an automation, the system or another agent — is a received note and is
// drawn in gray instead of amber.
export const isOwnPrivateNote = ({
  isPrivate,
  status,
  sender,
  senderType,
  senderId,
  currentUserId,
}) => {
  if (!isPrivate) return false;
  if (status === MESSAGE_STATUS.PROGRESS) return true;
  const type = (sender?.type ?? senderType ?? '').toLowerCase();
  const id = senderId ?? sender?.id;
  return (
    type === SENDER_TYPES.USER.toLowerCase() &&
    id != null &&
    Number(id) === Number(currentUserId)
  );
};

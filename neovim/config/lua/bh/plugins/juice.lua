return {
  "sphamba/smear-cursor.nvim",
  opts = {
    -- Sets animation framerate
    time_interval = 5, -- milliseconds

    -- Amount of time the cursor has to stay still before triggering animation.
    -- Useful if the target changes and rapidly comes back to its original position.
    -- E.g. when hitting a keybinding that triggers CmdlineEnter.
    -- Increase if the cursor makes weird jumps when hitting keys.
    delay_event_to_smear = 1, -- milliseconds

    -- Delay for `vim.on_key` to avoid redundancy with vim events triggers.
    delay_after_key = 5, -- milliseconds

    -- How fast the smear's head moves towards the target.
    -- 0: no movement, 1: instantaneous
    stiffness = 0.8,
  },
}

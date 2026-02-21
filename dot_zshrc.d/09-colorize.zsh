# ~/.zshrc.d/09-colorize.zsh
# Color test functions for terminal debugging

# 256-color palette
colortest() {
  for i in {0..255}; do
    printf "\x1b[38;5;%dm%3d " "$i" "$i"
    if (( (i + 1) % 16 == 0 )); then
      printf "\n"
    fi
  done
  printf "\x1b[0m\n"
}

# 256-color background palette
colortestbg() {
  for i in {0..255}; do
    printf "\x1b[48;5;%dm %3d " "$i" "$i"
    if (( (i + 1) % 16 == 0 )); then
      printf "\x1b[0m\n"
    fi
  done
  printf "\x1b[0m\n"
}

# True color (24-bit) gradient test
truecolortest() {
  local col
  local width=72
  printf "\n  24-bit (true) color test:\n  "
  for col in $(seq 0 $((width - 1))); do
    local r=$(( 255 - col * 255 / (width - 1) ))
    local g=$(( col * 510 / (width - 1) ))
    local b=$(( col * 255 / (width - 1) ))
    (( g > 255 )) && g=$(( 510 - g ))
    printf "\x1b[48;2;%d;%d;%dm " "$r" "$g" "$b"
  done
  printf "\x1b[0m\n\n"
}

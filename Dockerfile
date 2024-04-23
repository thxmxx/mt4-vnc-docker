FROM alpine

# Set environment variables for MetaTrader download and Wine version
ENV URL="https://download.mql5.com/cdn/web/metaquotes.software.corp/mt4/mt4oldsetup.exe"

RUN apk add --no-cache sudo git xfce4 faenza-icon-theme bash python3 tigervnc xfce4-terminal firefox cmake wget \
    pulseaudio xfce4-pulseaudio-plugin pavucontrol pulseaudio-alsa alsa-plugins-pulse alsa-lib-dev nodejs npm \
    build-base wine \
    && adduser -h /home/alpine -s /bin/bash -S -D alpine && echo -e "alpine\nalpine" | passwd alpine \
    && echo 'alpine ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
    && git clone https://github.com/novnc/noVNC /opt/noVNC \
    && git clone https://github.com/novnc/websockify /opt/noVNC/utils/websockify
    # && wget https://raw.githubusercontent.com/novaspirit/Alpine_xfce4_noVNC/dev/script.js -O /opt/noVNC/script.js \
    # && wget https://raw.githubusercontent.com/novaspirit/Alpine_xfce4_noVNC/dev/audify.js -O /opt/noVNC/audify.js \
    # && wget https://raw.githubusercontent.com/novaspirit/Alpine_xfce4_noVNC/dev/vnc.html -O /opt/noVNC/vnc.html \
    # && wget https://raw.githubusercontent.com/novaspirit/Alpine_xfce4_noVNC/dev/pcm-player.js -O /opt/noVNC/pcm-player.js

# Copy files from the current directory to the container
COPY script.js /opt/noVNC/script.js
COPY audify.js /opt/noVNC/audify.js
COPY vnc.html /opt/noVNC/vnc.html
COPY pcm-player.js /opt/noVNC/pcm-player.js
COPY disable-usb.reg /opt/noVNC/disable-usb.reg

RUN npm install --prefix /opt/noVNC ws
RUN npm install --prefix /opt/noVNC audify

USER alpine
WORKDIR /home/alpine

RUN mkdir -p /home/alpine/.vnc \
    && echo -e "-Securitytypes=none" > /home/alpine/.vnc/config \
    && echo -e "#!/bin/bash\nstartxfce4 &" > /home/alpine/.vnc/xstartup \
    && echo -e "alpine\nalpine\nn\n" | vncpasswd

USER root

RUN echo '\
#!/bin/bash \
/usr/bin/vncserver :99 2>&1 | sed  "s/^/[Xtigervnc ] /" & \
sleep 1 & \
/usr/bin/pulseaudio 2>&1 | sed  "s/^/[pulseaudio] /" & \
sleep 1 & \
/usr/bin/node /opt/noVNC/audify.js 2>&1 | sed "s/^/[audify    ] /" & \
/opt/noVNC/utils/novnc_proxy --vnc localhost:5999 2>&1 | sed "s/^/[noVNC     ] /"'\
>/entry.sh

USER alpine

# Download MetaTrader installer
RUN wget $URL -O mt4setup.exe
RUN WINEPREFIX=~/.mt4 winecfg -v=win10
RUN WINEPREFIX=~/.mt4 wine regedit /opt/noVNC/disable-usb.reg
# Start MetaTrader installer in 32 bit environment
RUN WINEPREFIX=~/.mt4 wine mt4setup.exe /S
# Install MetaTrader 4 using Wine
RUN WINEPREFIX=~/.mt4 wine mt4setup.exe /S /D= 'C:\\mt4'
RUN rm mt4setup.exe

ENTRYPOINT [ "/bin/bash", "/entry.sh" ]

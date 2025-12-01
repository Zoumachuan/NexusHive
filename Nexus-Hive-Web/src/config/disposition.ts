// 生成随机数
import { getRandomNumber } from '/@/utils/common'

export class Disposition {
    // 机舱
    cabin = {
        appId: import.meta.env.VITE_AGORA_CABIN_APPID,
        channel: import.meta.env.VITE_AGORA_CABIN_CHANNEL,
        token: '',
        uid: `12345`,
    }

    // 飞行器
    drone = {
        appId: import.meta.env.VITE_AGORA_DRONE_APPID,
        channel: import.meta.env.VITE_AGORA_DRONE_CHANNEL,
        token: '',
        uid: `54321`,
    }

    djiDock = {
        gateway_sn: '7CTXN3S00B08GE',
        videoId: '',
        camera_index: '165-0-7',
        video_index: 'normal-0',
    }

    device = {
        device_sn: '1581F6QAD247P00GJZWY',
        camera_index: '80-0-0',
        video_index: 'normal-0',
        videoId: '',
    }

    constructor() {}

    // 设置DJI Dock videoId
    setDjiDockVideoId(sn: string) {
        this.djiDock.gateway_sn = sn
        this.djiDock.videoId = `${this.djiDock.gateway_sn}/${this.djiDock.camera_index}/${this.djiDock.video_index}`
    }

    // 设置无人机 videoId
    setDeviceVideoId(sn: string) {
        this.device.device_sn = sn
        this.device.videoId = `${this.device.device_sn}/${this.device.camera_index}/${this.device.video_index}`
    }

    // 获取DJI Dock数据
    getDjiDockData() {
        this.djiDock.videoId = `${this.djiDock.gateway_sn}/${this.djiDock.camera_index}/${this.djiDock.video_index}`
        return {
            url_type: 0,
            url: `channel=${this.cabin.channel}&sn=${this.djiDock.gateway_sn}&token=${encodeURIComponent(this.cabin.token)}&uid=${this.cabin.uid}`,
            video_id: this.djiDock.videoId,
            video_quality: 4,
        }
    }

    // 获取DJI Dock数据 rtmp
    getDjiDockRtmpData() {
        this.djiDock.videoId = `${this.djiDock.gateway_sn}/${this.djiDock.camera_index}/${this.djiDock.video_index}`
        return {
            url_type: 1,
            url: `rtmp://117.172.206.47/live/7c5fe99c6f5f?secret=1DBC9858BC3E405B`,
            video_id: this.djiDock.videoId,
            video_quality: 4,
        }
    }

    // 无人机的数据
    getDeviceData() {
        this.device.videoId = `${this.device.device_sn}/${this.device.camera_index}/${this.device.video_index}`
        return {
            url_type: 0,
            url: `channel=${this.drone.channel}&sn=${this.device.device_sn}&token=${encodeURIComponent(this.drone.token)}&uid=${this.drone.uid}`,
            video_id: this.device.videoId,
            video_quality: 0,
        }
    }
}

export const disposition = new Disposition()

<template>
    <div style="display: flex; flex-direction: column; width: 100%; height: 100%">
        <video ref="videoElement" controls autoplay muted playsinline class="video-player" />
        <div class="status">
            <span>播放状态: {{ status }}</span>
            <button @click="play">播放</button>
            <button @click="destroy">停止</button>
            <button @click="close">关闭</button>
        </div>
    </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import flvjs from 'flv.js'
import { useMapStore } from '/@/stores/map'
import { storeToRefs } from 'pinia'
// ------------------------- 生命周期 -------------------------

// ------------------------- 计算属性 -------------------------

// ------------------------- 变量 -------------------------
const mapStore = useMapStore()
const { isShowCabinLive } = storeToRefs(mapStore)
const videoElement = ref(null)
const flvPlayer = ref(null)
const status = ref('未开始')

const streamUrl = 'rtmp://117.172.206.47/live/7c5fe99c6f5f?secret=1DBC9858BC3E405B'
// ------------------------- 监听 -------------------------

// ------------------------- 方法 -------------------------

const play = () => {
    if (flvjs.isSupported() && videoElement.value) {
        status.value = '初始化中...'
        flvPlayer.value = flvjs.createPlayer({
            type: 'flv',
            url: streamUrl,
            isLive: true,
        })
        console.log(flvPlayer.value)

        flvPlayer.value.attachMediaElement(videoElement.value)
        flvPlayer.value.load()
        flvPlayer.value.play()

        flvPlayer.value.on(flvjs.Events.LOADING_COMPLETE, () => {
            status.value = '加载完成'
        })

        flvPlayer.value.on(flvjs.Events.ERROR, (errorType, errorDetail) => {
            console.error('播放错误:', errorType, errorDetail)
            status.value = `错误: ${errorType}`
        })

        flvPlayer.value.on(flvjs.Events.METADATA_ARRIVED, () => {
            status.value = '开始播放'
        })

        flvPlayer.value.play().catch((err) => {
            console.error('播放失败:', err)
            status.value = '播放失败'
        })
    } else {
        status.value = '浏览器不支持FLV播放'
    }
}

const pause = () => {
    if (flvPlayer.value) {
        flvPlayer.value.pause()
    }
}

const destroy = () => {
    if (flvPlayer.value) {
        flvPlayer.value.destroy()
        flvPlayer.value = null
    }
}

const close = () => {
    if (flvPlayer.value) {
        flvPlayer.value.destroy()
        flvPlayer.value = null
    }
    isShowCabinLive.value = false
}

defineExpose({
    play,
    pause,
    destroy,
})
</script>

<style scoped lang="scss">
.video-player {
    width: 100%;
    flex: 1;
}
.status {
    margin-top: 10px;
    padding: 10px;
    background: #f5f5f5;
    border-radius: 4px;
}

button {
    margin: 0 5px;
    padding: 5px 15px;
    border: none;
    border-radius: 4px;
    background: #007bff;
    color: white;
    cursor: pointer;
}
</style>

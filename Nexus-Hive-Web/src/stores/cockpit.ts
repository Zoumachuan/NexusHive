import { defineStore } from 'pinia'

export const useCockpit = defineStore('cockpit', {
    state: (): any => {
        return {
            // 弹窗
            isShow: false,
            // 当前航线信息
            currentLane: {},
            // 一键起飞任务id
            flightId: '',
            // 加载中
            loading: false,
        }
    },
    actions: {
        // 打开弹窗
        open() {
            this.isShow = true
        },
        // 关闭弹窗
        close() {
            this.isShow = false
        },
        // 一键起飞任务id
        setFlightId(id: string) {
            this.flightId = id
        },
        // 加载中
        setLoading(loading: boolean) {
            this.loading = loading
        },
    },
    getters: {},
})

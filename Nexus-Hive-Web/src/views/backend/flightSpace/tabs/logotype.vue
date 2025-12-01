<template>
    <div class="logotype">
        <div class="logotype-header">
            <div class="logotype-header-left">地图模型</div>
            <!-- <el-icon style="cursor: pointer"><Plus /></el-icon> -->
        </div>
        <div>
            <el-collapse>
                <el-collapse-item name="1">
                    <template #title="{ isActive }">
                        <div :class="['title-wrapper', { 'is-active': isActive }]">
                            <div class="title-wrapper-left">
                                <span>{{ currentProject.name }}</span>
                            </div>
                            <div class="title-wrapper-right">共{{ modelList.length }}处</div>
                        </div>
                    </template>
                    <div class="logotype-content">
                        <div
                            :class="{ 'logotype-item-active': activeIndex == `1-${index}` }"
                            class="logotype-item"
                            v-for="(item, index) in modelList"
                            :key="index"
                            @click="handleItem(item, `1-${index}`)"
                        >
                            <div class="logotype-item-left">
                                <img class="logotype-item-image" src="/img/image/ban-icon.png" alt="" />
                                <span>{{ item.name }}</span>
                            </div>
                            <div class="logotype-item-right">
                                <img class="logotype-item-image" src="/img/image/ban-icon2.png" alt="" />
                                <el-popconfirm class="box-item" title="是否确认要删除该地图模型？" placement="top" @confirm="handleDelete(item)">
                                    <template #reference>
                                        <img class="logotype-item-image" src="/img/image/ban-icon1.png" alt="" />
                                    </template>
                                </el-popconfirm>
                            </div>
                        </div>
                    </div>
                </el-collapse-item>
            </el-collapse>
        </div>
    </div>
</template>

<script setup lang="ts">
import { ref, inject, watch, provide, onMounted } from 'vue'
import { useMqttStore } from '/@/stores/mqtt'
import { baTableApi } from '/@/api/common'
import { Plus } from '@element-plus/icons-vue'
import { useProjectStore } from '/@/stores/project'
import { storeToRefs } from 'pinia'

onMounted(() => {
    getModelList()
})

const mqttStore = useMqttStore()

const projectStore = useProjectStore()
const { currentProject, aerodromeList } = storeToRefs(projectStore)

watch(currentProject, async (val) => {
    await getModelList()
})

const activeIndex = ref('')

// 地图模型列表
const modelList = ref([])

// 地图模型
const api = new baTableApi('/admin/modemanage/')

// 获取模型列表
const getModelList = async () => {
    const res = await api.index({
        search: [
            { field: 'project_id', val: currentProject.value?.id, operator: '=' },
            { field: 'status', val: 1, operator: '=' },
        ],
    })
    modelList.value = res.data.list || []
}

// 删除地图模型
const handleDelete = async (item: any) => {
    await api.del({
        id: item.id,
    })
    getModelList()
}

const handleItem = (item: any, index: string) => {
    activeIndex.value = index
}
</script>

<style scoped lang="scss">
.logotype {
    width: 100%;
    height: 100%;

    &-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        font-size: 14px;
        font-weight: bold;
        border-bottom: 1px solid #e5e5e5;
        padding-bottom: 10px;
    }

    .title-wrapper {
        width: 100%;
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-right: 10px;

        .title-wrapper-left {
            display: flex;
            align-items: center;
            gap: 4px;

            .title-wrapper-image {
                width: 16px;
                height: 16px;
            }

            span {
                font-size: 14px;
            }
        }

        .title-wrapper-right {
            color: #00000099;
            font-size: 12px;
        }
    }

    .logotype-content {
        width: 100%;
        padding: 0 10px;
        display: flex;
        flex-direction: column;
        border-left: 1px solid #e5e5e5;

        .logotype-item {
            width: 100%;
            height: 30px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            cursor: pointer;
            border-radius: 4px;

            &:hover {
                background: #f6f6f6;
            }

            &-active {
                background: #daf4ff;
            }

            &-left {
                display: flex;
                align-items: center;
                color: #000000;
                padding: 0 10px;
                gap: 10px;

                .logotype-item-image {
                    width: 16px;
                    height: 16px;
                }
            }

            &-right {
                display: flex;
                align-items: center;
                gap: 10px;

                .logotype-item-image {
                    width: 16px;
                    height: 16px;
                }
            }
        }
    }
}
</style>

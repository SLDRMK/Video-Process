#!/bin/bash
# 批量将视频文件转为30fps的mp4，支持裁剪和旋转功能
# 用法: ./webm2mp4.sh [视频路径] [入点秒数] [出点秒数] [旋转角度]
# 示例: ./webm2mp4.sh "视频文件.mp4" 5 15 90  # 从第5秒裁剪到第15秒，顺时针旋转90度
# 示例: ./webm2mp4.sh "视频文件.webm" "" "" 180  # 完整转换，顺时针旋转180度
# 示例: ./webm2mp4.sh "视频文件.avi"     # 完整转换，默认不旋转

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示帮助信息
show_help() {
    echo -e "${BLUE}视频转换工具${NC}"
    echo "用法: $0 [视频路径] [入点秒数] [出点秒数] [旋转角度]"
    echo ""
    echo "参数说明:"
    echo "  视频路径    支持 .mp4, .webm, .avi, .mkv 等格式"
    echo "  入点秒数    开始裁剪的时间点（可选，使用空字符串跳过）"
    echo "  出点秒数    结束裁剪的时间点（可选，使用空字符串跳过）"
    echo "  旋转角度    顺时针旋转角度：0, 90, 180, 270（可选，默认0度）"
    echo ""
    echo "示例:"
    echo "  $0 \"video.mp4\"           # 完整转换，默认不旋转"
    echo "  $0 \"video.webm\" 5 15     # 从第5秒裁剪到第15秒，默认不旋转"
    echo "  $0 \"video.avi\" \"\" \"\" 180  # 完整转换，旋转180度"
    echo "  $0 \"video.mov\" \"\" \"\" 0    # 完整转换，不旋转"
    echo "  $0 \"video.mp4\" 0 10 270  # 从开始裁剪到第10秒，旋转270度"
    echo ""
    echo "支持格式: mp4, webm, avi, mkv, mov, flv, wmv"
    echo "旋转角度: 0度（默认，不旋转）, 90度, 180度, 270度"
}

# 检查参数
if [ $# -eq 0 ]; then
    show_help
    exit 1
fi

VIDEO_PATH="$1"
START_TIME=""
END_TIME=""
ROTATION_ANGLE="0"  # 默认不旋转
CROP_OPTION=""
ROTATION_OPTION=""

# 检查视频文件是否存在
if [ ! -f "$VIDEO_PATH" ]; then
    echo -e "${RED}错误: 视频文件不存在: $VIDEO_PATH${NC}"
    exit 1
fi

# 检查文件扩展名
FILE_EXT="${VIDEO_PATH##*.}"
SUPPORTED_FORMATS="mp4 webm avi mkv mov flv wmv"
if [[ ! " $SUPPORTED_FORMATS " =~ " $FILE_EXT " ]]; then
    echo -e "${YELLOW}警告: 不支持的格式 '$FILE_EXT'，但会尝试转换${NC}"
fi

# 处理参数
case $# in
    1)  # 只有视频路径，使用默认设置
        echo -e "${BLUE}完整转换模式: 不裁剪，默认不旋转${NC}"
        ;;
    2)  # 视频路径 + 旋转角度
        ROTATION_ANGLE="$2"
        echo -e "${BLUE}完整转换模式: 不裁剪，旋转${ROTATION_ANGLE}度${NC}"
        ;;
    3)  # 视频路径 + 入点 + 出点
        START_TIME="$2"
        END_TIME="$3"
        if [ -n "$START_TIME" ] && [ -n "$END_TIME" ]; then
            CROP_OPTION="-ss $START_TIME -to $END_TIME"
            echo -e "${BLUE}裁剪模式: 从 ${START_TIME}秒 到 ${END_TIME}秒，默认不旋转${NC}"
        else
            echo -e "${BLUE}完整转换模式: 不裁剪，旋转${END_TIME}度${NC}"
            ROTATION_ANGLE="$3"
        fi
        ;;
    4)  # 视频路径 + 入点 + 出点 + 旋转角度
        START_TIME="$2"
        END_TIME="$3"
        ROTATION_ANGLE="$4"
        if [ -n "$START_TIME" ] && [ -n "$END_TIME" ]; then
            CROP_OPTION="-ss $START_TIME -to $END_TIME"
            echo -e "${BLUE}裁剪模式: 从 ${START_TIME}秒 到 ${END_TIME}秒，旋转${ROTATION_ANGLE}度${NC}"
        else
            echo -e "${BLUE}完整转换模式: 不裁剪，旋转${ROTATION_ANGLE}度${NC}"
        fi
        ;;
    *)
        echo -e "${RED}错误: 参数数量不正确${NC}"
        show_help
        exit 1
        ;;
esac

# 验证旋转角度
if [[ ! "$ROTATION_ANGLE" =~ ^(0|90|180|270)$ ]]; then
    echo -e "${RED}错误: 旋转角度必须是 0, 90, 180 或 270${NC}"
    exit 1
fi

# 设置旋转选项
case $ROTATION_ANGLE in
    0)   ROTATION_OPTION="" ;;
    90)  ROTATION_OPTION="transpose=1" ;;
    180) ROTATION_OPTION="transpose=1,transpose=1" ;;
    270) ROTATION_OPTION="transpose=2" ;;
esac

# 获取视频信息
echo -e "${YELLOW}正在分析视频信息...${NC}"
VIDEO_INFO=$(ffprobe -v quiet -print_format json -show_format -show_streams "$VIDEO_PATH" 2>/dev/null)

if [ $? -ne 0 ]; then
    echo -e "${RED}错误: 无法读取视频文件信息${NC}"
    exit 1
fi

# 提取视频信息
ORIGINAL_FPS=$(echo "$VIDEO_INFO" | jq -r '.streams[] | select(.codec_type=="video") | .r_frame_rate' | head -1)
DURATION=$(echo "$VIDEO_INFO" | jq -r '.format.duration' | head -1)
WIDTH=$(echo "$VIDEO_INFO" | jq -r '.streams[] | select(.codec_type=="video") | .width' | head -1)
HEIGHT=$(echo "$VIDEO_INFO" | jq -r '.streams[] | select(.codec_type=="video") | .height' | head -1)
CODEC=$(echo "$VIDEO_INFO" | jq -r '.streams[] | select(.codec_type=="video") | .codec_name' | head -1)
BITRATE=$(echo "$VIDEO_INFO" | jq -r '.format.bit_rate' | head -1)

# 计算FPS（如果格式是分数）
if [[ "$ORIGINAL_FPS" == *"/"* ]]; then
    NUM=$(echo "$ORIGINAL_FPS" | cut -d'/' -f1)
    DEN=$(echo "$ORIGINAL_FPS" | cut -d'/' -f2)
    ORIGINAL_FPS=$(echo "scale=2; $NUM/$DEN" | bc)
fi

# 格式化时长
DURATION_FORMATTED=$(printf "%.2f" "$DURATION")
if [ -n "$CROP_OPTION" ]; then
    CROP_DURATION=$(echo "$END_TIME - $START_TIME" | bc)
    CROP_DURATION_FORMATTED=$(printf "%.2f" "$CROP_DURATION")
fi

# 显示视频信息
echo -e "${GREEN}=== 视频信息 ===${NC}"
echo -e "文件路径: ${BLUE}$VIDEO_PATH${NC}"
echo -e "原始格式: ${BLUE}$FILE_EXT${NC}"
echo -e "视频编码: ${BLUE}$CODEC${NC}"
echo -e "分辨率: ${BLUE}${WIDTH}x${HEIGHT}${NC}"
echo -e "原始帧率: ${BLUE}${ORIGINAL_FPS} fps${NC}"
echo -e "视频时长: ${BLUE}${DURATION_FORMATTED}秒${NC}"
echo -e "比特率: ${BLUE}$(echo "scale=0; $BITRATE/1000" | bc) kbps${NC}"

if [ -n "$CROP_OPTION" ]; then
    echo -e "裁剪区间: ${BLUE}${START_TIME}s - ${END_TIME}s${NC}"
    echo -e "裁剪时长: ${BLUE}${CROP_DURATION_FORMATTED}秒${NC}"
fi

echo -e "${GREEN}=== 转换设置 ===${NC}"
echo -e "目标帧率: ${BLUE}30 fps${NC}"
echo -e "目标格式: ${BLUE}MP4 (H.264)${NC}"
echo -e "音频编码: ${BLUE}AAC${NC}"
echo -e "旋转角度: ${BLUE}${ROTATION_ANGLE}度${NC}"

# 调整分辨率（确保为偶数）
WIDTH_EVEN=$((WIDTH/2*2))
HEIGHT_EVEN=$((HEIGHT/2*2))
if [ "$WIDTH" != "$WIDTH_EVEN" ] || [ "$HEIGHT" != "$HEIGHT_EVEN" ]; then
    echo -e "分辨率调整: ${BLUE}${WIDTH}x${HEIGHT} → ${WIDTH_EVEN}x${HEIGHT_EVEN}${NC}"
fi

# 生成输出文件名（默认输出到原视频所在目录）
VIDEO_DIR=$(dirname "$VIDEO_PATH")
BASE_NAME=$(basename "$VIDEO_PATH" ".$FILE_EXT")
if [ -n "$CROP_OPTION" ]; then
    OUTPUT_NAME="${BASE_NAME}_${START_TIME}s-${END_TIME}s_rot${ROTATION_ANGLE}_30fps.mp4"
else
    OUTPUT_NAME="${BASE_NAME}_rot${ROTATION_ANGLE}_30fps.mp4"
fi
OUTPUT_FILE="${VIDEO_DIR}/${OUTPUT_NAME}"

echo -e "输出文件: ${BLUE}$OUTPUT_FILE${NC}"
echo ""

# 确认转换
read -p "是否开始转换? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}转换已取消${NC}"
    exit 0
fi

echo -e "${YELLOW}开始转换...${NC}"

# 执行转换
if [ -n "$ROTATION_OPTION" ]; then
    ffmpeg -y $CROP_OPTION -i "$VIDEO_PATH" -r 30 -vf "$ROTATION_OPTION,scale=${WIDTH_EVEN}:${HEIGHT_EVEN}" \
        -c:v libx264 -preset medium -crf 23 -c:a aac -b:a 128k "$OUTPUT_FILE"
else
    ffmpeg -y $CROP_OPTION -i "$VIDEO_PATH" -r 30 -vf "scale=${WIDTH_EVEN}:${HEIGHT_EVEN}" \
        -c:v libx264 -preset medium -crf 23 -c:a aac -b:a 128k "$OUTPUT_FILE"
fi

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 转换完成: $OUTPUT_FILE${NC}"
    
    # 显示输出文件信息
    if [ -f "$OUTPUT_FILE" ]; then
        OUTPUT_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
        echo -e "${GREEN}输出文件大小: ${BLUE}${OUTPUT_SIZE}${NC}"
    fi
else
    echo -e "${RED}✗ 转换失败${NC}"
    exit 1
fi

echo -e "${GREEN}转换完成！${NC}" 
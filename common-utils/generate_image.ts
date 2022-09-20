import {join} from 'path';
import { writeFileSync } from 'fs';
import { createCanvas, loadImage } from 'canvas';

const getRandomIndex = () => {
    return Math.ceil(Math.random() * 6);
}

const getRandomBgPath = () => {
    const index = getRandomIndex();
    return join('assets', `cat${index}.png`);
}

const bgColors = ['#4f6a8f', '#d99477', '#35b5ff', '#2e9599', '#a8216b', '#f26d50'];
const getRandomBgColor = () => {
    return bgColors[getRandomIndex() - 1];
}

const generateImg = async (filePath: string) => {
    const canvas = createCanvas(800, 800);
    const ctx = canvas.getContext('2d');
    
    // set bg
    ctx.fillStyle = getRandomBgColor();
    ctx.fillRect(0, 0, 800, 800);
    
    // draw text
    ctx.fillStyle = '#fff';

    ctx.font = 'bold 30px Helvetica';
    ctx.fillText(`NFT Bargain`, 50, 650);

    ctx.font = '22px Helvetica';
    ctx.fillText(`助力人数：${getRandomIndex()} 人`, 50, 700);

    ctx.font = '22px Helvetica';
    ctx.fillText(`0xcCBF6a0fF28072453Cb5ac5F220ED2475EF8d25f`, 50, 750);

    // draw bg
    const bgCat = await loadImage(getRandomBgPath());
    ctx.drawImage(bgCat, 352, 100);

    // draw bg2
    const bgCat2 = await loadImage(getRandomBgPath());
    ctx.drawImage(bgCat2, 352, 200);

    // draw bg3
    const bgCat3 = await loadImage(getRandomBgPath());
    ctx.drawImage(bgCat3, 352, 300);

    writeFileSync(filePath, canvas.toBuffer('image/png'));
    console.log(`✅ create image saved to path: ${filePath}`);
}

const main = async () => {
    for (let i = 0; i < 10; i++) {
        await generateImg(join('out', `${i}.png`));
    }
}

main();
document.addEventListener('DOMContentLoaded', function() {
    // Create the color swatch bar first
    const colorSwatchBar = addItem('div', {
        id: 'colorSwatchBar',
        className: 'color-swatch-bar'
    });
    document.body.appendChild(colorSwatchBar); // Or append to another container
    
    // Then initialize the color swatches
    const colorValues = getComputedStyle(document.documentElement)
        .getPropertyValue('--mb-swatches-hi')
        .match(/hsl\([^)]*\)/g);
    
    if (colorValues) {
        colorValues.forEach((value, index) => {
            const appleColor = [0, 1, 1, 0, 1, 1, 1, 0, 0, 1, 0, 1, 1];
            const colorSwatch = addItem('span', {
                className: 'color-swatch',
                innerHTML: appleColor[index] == 1 ? '<i class="fa-brands fa-apple"></i>' : '',
                style: {
                    backgroundColor: value,
                },
            });
            colorSwatch.addEventListener('click', (event) => {
                event.stopPropagation();
                mb.accentColor = index;
                applyAccent();
            });
            colorSwatchBar.append(colorSwatch);
        });
    }
});
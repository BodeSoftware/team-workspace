/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      typography: {
        DEFAULT: {
          css: {
            maxWidth: 'none',
            img: {
              marginTop: '1.5em',
              marginBottom: '1.5em',
            },
            'ul > li > p': {
              marginTop: '0',
              marginBottom: '0',
            },
            'ol > li > p': {
              marginTop: '0',
              marginBottom: '0',
            },
          },
        },
      },
    },
  },
  plugins: [
    require('@tailwindcss/typography'),
  ],
};
